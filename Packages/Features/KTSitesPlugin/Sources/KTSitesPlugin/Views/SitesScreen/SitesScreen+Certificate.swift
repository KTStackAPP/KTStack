import AppKit
import KTPlatformContracts
import SwiftUI

extension SitesScreen {
    func chooseCertificate(_ site: SiteSummary) {
        guard let cert = pickFile("Choose certificate (fullchain.pem)"),
              let key = pickFile("Choose private key")
        else { return }
        importCertificate(site, certPath: cert.path, keyPath: key.path)
    }

    func reimportCertificate(_ site: SiteSummary) {
        guard let current = site.customCertificate else { return }
        importCertificate(site, certPath: current.sourceCertPath, keyPath: current.sourceKeyPath)
    }

    func removeCertificate(_ site: SiteSummary) {
        actionError = nil
        Task {
            do {
                try await vm.removeCustomCertificate(site.id)
                feedback.toast("Removed the custom certificate from \(site.domain)")
            } catch {
                actionError = "Couldn't remove the certificate from \(site.domain): \(error.localizedDescription)"
            }
        }
    }

    private func importCertificate(_ site: SiteSummary, certPath: String, keyPath: String) {
        actionError = nil
        Task {
            do {
                try await vm.importCertificate(site.id, certPath: certPath, keyPath: keyPath)
                feedback.toast("\(site.domain) now serves the imported certificate")
            } catch {
                actionError = "Couldn't import the certificate for \(site.domain): \(error.localizedDescription)"
            }
        }
    }

    private func pickFile(_ title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = title
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}
