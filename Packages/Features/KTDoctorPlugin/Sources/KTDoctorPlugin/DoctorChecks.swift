import Foundation
import KTPlatformContracts
import KTPluginKit
import KTStackCore

/// Từng check là hàm thuần trên `any DoctorProbing`, không đụng hệ thống trực tiếp và không sửa gì.
enum DoctorChecks {
    static func helper(_ state: DoctorHelperState) -> DoctorCheck {
        let title = "Privileged helper"
        switch state.registration {
        case .notApplicable:
            return DoctorCheck(
                id: "helper", title: title, status: .warn,
                detail: "This build has no Developer ID signature, so the helper is not used. DNS falls back to an admin password prompt.",
                remedy: "Expected for local builds. Use a signed release to get the helper."
            )
        case .notRegistered:
            return DoctorCheck(
                id: "helper", title: title, status: .fail,
                detail: "The helper is not registered with launchd, so DNS and CA trust cannot be applied.",
                remedy: "Restart KTStack to register it. If it stays unregistered, reinstall the app.",
                action: .openLoginItems
            )
        case .requiresApproval:
            return DoctorCheck(
                id: "helper", title: title, status: .fail,
                detail: "The helper is registered but waiting for approval in Login Items.",
                remedy: "Allow KTStack in System Settings > General > Login Items.",
                action: .openLoginItems
            )
        case .enabled:
            if let error = state.error {
                return DoctorCheck(
                    id: "helper", title: title, status: .fail,
                    detail: "The helper is enabled but did not answer over XPC: \(error)",
                    remedy: "Quit and reopen KTStack. If it persists, toggle KTStack off and on in Login Items.",
                    action: .openLoginItems
                )
            }
            // So với hằng số dùng chung, không với version app: cái cần bắt là helper cũ còn đăng ký.
            let expected = HelperIdentity.bundleVersion
            let version = state.version ?? "unknown"
            if version != expected {
                return DoctorCheck(
                    id: "helper", title: title, status: .warn,
                    detail: "The registered helper reports \(version), this build ships \(expected).",
                    remedy: "Quit and reopen KTStack so the new helper takes over."
                )
            }
            return DoctorCheck(
                id: "helper", title: title, status: .pass,
                detail: "Registered, answering XPC, version \(version)."
            )
        }
    }

    static func dns(tld: String, probes: any DoctorProbing) -> DoctorCheck {
        let title = "DNS"
        let resolver = URL(fileURLWithPath: DNSConstants.resolverPath(for: tld))
        guard let contents = probes.readFile(resolver) else {
            return DoctorCheck(
                id: "dns", title: title, status: .fail,
                detail: "\(resolver.path) is missing, so .\(tld) hostnames do not resolve.",
                remedy: "Enable DNS on the Services screen.",
                action: .openServices
            )
        }
        guard pointsAtLoopbackResolver(contents) else {
            return DoctorCheck(
                id: "dns", title: title, status: .fail,
                detail: "\(resolver.path) does not point at 127.0.0.1 port \(DNSConstants.dnsPort).",
                remedy: "Reset DNS on the Services screen.",
                action: .openServices
            )
        }

        let probeHost = "probe.\(tld)"
        let addresses = probes.resolveHost(probeHost)
        guard addresses.contains("127.0.0.1") else {
            let seen = addresses.isEmpty ? "nothing" : addresses.joined(separator: ", ")
            return DoctorCheck(
                id: "dns", title: title, status: .fail,
                detail: "The resolver file is in place but \(probeHost) resolves to \(seen).",
                remedy: "Reset DNS on the Services screen, then check that dnsmasq is running.",
                action: .openServices
            )
        }
        return DoctorCheck(
            id: "dns", title: title, status: .pass,
            detail: "\(resolver.path) is in place and \(probeHost) resolves to 127.0.0.1."
        )
    }

    static func tls(tld: String, paths: AppSupportPaths, probes: any DoctorProbing) -> DoctorCheck {
        let title = "Local TLS"
        let manageCA = "Open Settings and manage the local certificate authority under Local HTTPS certificates."
        guard probes.fileExists(paths.caRootCert) else {
            return DoctorCheck(
                id: "tls", title: title, status: .fail,
                detail: "No local CA has been generated, so certificates for .\(tld) sites cannot be issued.",
                remedy: manageCA,
                action: .openSettings
            )
        }
        guard probes.isCATrusted(paths.caRootCert) else {
            return DoctorCheck(
                id: "tls", title: title, status: .fail,
                detail: "The local CA exists but is not trusted in the System Keychain, so browsers reject site certificates.",
                remedy: manageCA,
                action: .openSettings
            )
        }
        guard probes.fileExists(paths.certsDir) else {
            return DoctorCheck(
                id: "tls", title: title, status: .warn,
                detail: "The CA is trusted but \(displayPath(paths.certsDir)) is missing, so per-site certificates were not minted.",
                remedy: "Restart the web server on the Services screen to mint them again.",
                action: .openServices
            )
        }
        return DoctorCheck(
            id: "tls", title: title, status: .pass,
            detail: "Local CA is present and trusted in the System Keychain."
        )
    }

    static func ports(probes: any DoctorProbing) -> DoctorCheck {
        var details: [String] = []
        var statuses: [DoctorStatus] = []
        var conflicts: [String] = []

        for port in [80, 443] {
            let state = probes.portState(port)
            switch state {
            case .free:
                details.append(":\(port) free")
                statuses.append(.pass)
            // Front terminator là nginx, nên nginx giữ 80/443 là bình thường.
            case let .inUse(owner, _) where owner == "nginx":
                details.append(":\(port) held by nginx")
                statuses.append(.pass)
            case let .inUse(owner, message):
                details.append(":\(port) held by \(owner ?? "another process")")
                conflicts.append(message)
                statuses.append(.fail)
            case let .unavailable(message):
                details.append(":\(port) could not be probed")
                conflicts.append(message)
                statuses.append(.warn)
            }
        }

        if let conflict = probes.udp53Conflict() {
            details.append(":53 held by \(conflict.process)")
            conflicts.append(conflict.message)
            statuses.append(.fail)
        } else {
            details.append(":53 free or held by KTStack dnsmasq")
            statuses.append(.pass)
        }

        return DoctorCheck(
            id: "ports", title: "Ports", status: DoctorStatus.worst(statuses),
            detail: details.joined(separator: ", ") + ".",
            remedy: conflicts.first
        )
    }

    static func binaries(probes: any DoctorProbing) -> DoctorCheck {
        var missing: [String] = []
        var invalid: [String] = []
        var verified = 0
        for item in probes.stagedBinaries {
            guard probes.fileExists(item.url) else {
                if item.required { missing.append(item.name) }
                continue
            }
            if probes.verifySignature(item.url) { verified += 1 } else { invalid.append(item.name) }
        }

        if !invalid.isEmpty {
            return DoctorCheck(
                id: "binaries", title: "Staged binaries", status: .fail,
                detail: "Code signature check failed for \(invalid.joined(separator: ", ")).",
                remedy: "Reinstall KTStack from the DMG so the binaries are staged again."
            )
        }
        if !missing.isEmpty {
            return DoctorCheck(
                id: "binaries", title: "Staged binaries", status: .fail,
                detail: "Not staged: \(missing.joined(separator: ", ")).",
                remedy: "Restart KTStack to stage them, or reinstall from the DMG."
            )
        }
        return DoctorCheck(
            id: "binaries", title: "Staged binaries", status: .pass,
            detail: "\(verified) staged binaries pass the signature check."
        )
    }

    static func services(probes: any DoctorProbing) -> DoctorCheck {
        var crashed: [String] = []
        var loaded: [String] = []

        for job in probes.launchdJobs {
            guard let state = probes.launchdJobState(job.label) else { continue }
            loaded.append(job.name)
            if state.failedStart { crashed.append("\(job.name) (last exit \(state.lastExitCode ?? 0))") }
        }

        if !crashed.isEmpty {
            return DoctorCheck(
                id: "services", title: "Services", status: .fail,
                detail: "launchd reports a failed start for \(crashed.joined(separator: ", ")).",
                remedy: "Open the service's log on the Logs screen, then restart it on Services.",
                action: .openServices
            )
        }
        if loaded.isEmpty {
            return DoctorCheck(
                id: "services", title: "Services", status: .warn,
                detail: "No KTStack service is loaded in launchd.",
                remedy: "Start the stack from the Services screen.",
                action: .openServices
            )
        }
        return DoctorCheck(
            id: "services", title: "Services", status: .pass,
            detail: "Loaded without a failed start: \(loaded.joined(separator: ", "))."
        )
    }

    static func php(paths: AppSupportPaths, probes: any DoctorProbing) -> DoctorCheck {
        let title = "PHP"
        let defaultVersion = probes.defaultPHPVersion
        let versions = probes.installedPHPVersions
        guard versions.contains(defaultVersion) else {
            return DoctorCheck(
                id: "php", title: title, status: .fail,
                detail: "PHP \(defaultVersion) is not installed, so PHP sites cannot be served.",
                remedy: "Install PHP \(defaultVersion) on the Runtimes screen.",
                action: .openRuntimes
            )
        }

        // Socket vắng khi pool đang chạy mới là hỏng; stack dừng hẳn thì stop() đã xóa socket.
        let brokenPools = versions.filter { version in
            probes.launchdJobState(probes.phpPoolLabel(version)) != nil
                && !probes.fileExists(paths.phpFpmSocket(version))
        }
        if !brokenPools.isEmpty {
            return DoctorCheck(
                id: "php", title: title, status: .fail,
                detail: "PHP-FPM is running for \(brokenPools.joined(separator: ", ")) but the pool sockets are missing.",
                remedy: "Restart PHP-FPM on the Services screen.",
                action: .openServices
            )
        }
        return DoctorCheck(
            id: "php", title: title, status: .pass,
            detail: "Installed: \(versions.joined(separator: ", ")). Default \(defaultVersion)."
        )
    }

    static func pointsAtLoopbackResolver(_ contents: String) -> Bool {
        let fields = contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return fields.contains("nameserver 127.0.0.1") && fields.contains("port \(DNSConstants.dnsPort)")
    }

    /// Report và UI không lộ tên user: mọi path dưới home hiển thị dạng ~/…
    static func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard url.path.hasPrefix(home) else { return url.path }
        return "~" + url.path.dropFirst(home.count)
    }
}
