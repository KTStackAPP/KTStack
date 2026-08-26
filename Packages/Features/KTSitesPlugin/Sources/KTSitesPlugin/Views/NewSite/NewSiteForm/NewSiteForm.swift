import AppKit
import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

enum NewSiteMode: Hashable { case create, importFolder, proxy }

struct NewSiteForm: View {
    @ObservedObject var model: NewSiteModel
    let provisioning: any SiteProvisioning
    let availableVersions: [String]
    let sitesRoot: URL
    let tld: String
    let defaultPHPVersion: String
    var defaultHTTPS = true
    let onClose: () -> Void

    @State var mode: NewSiteMode = .create
    @State var name = ""
    @State var kind: NewSiteKind = .empty
    @State var phpVersion: String
    @State var adminPassword = NewSiteForm.randomPassword()
    @State var advanced = false
    @State var serveHTTPS = true
    @State var createDatabase = false
    @State var importFolder: URL?
    @State var importName = ""
    @State var proxyTarget = ""

    init(
        model: NewSiteModel,
        provisioning: any SiteProvisioning,
        availableVersions: [String],
        sitesRoot: URL,
        tld: String,
        defaultPHPVersion: String,
        defaultHTTPS: Bool = true,
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.provisioning = provisioning
        self.availableVersions = availableVersions
        self.sitesRoot = sitesRoot
        self.tld = tld
        self.defaultPHPVersion = defaultPHPVersion
        self.defaultHTTPS = defaultHTTPS
        self.onClose = onClose
        _phpVersion = State(initialValue: defaultPHPVersion)
    }

    var slug: String {
        DomainSlug.make(name)
    }

    var domain: String {
        "\(slug).\(tld)"
    }

    var importSlug: String {
        DomainSlug.make(importName)
    }

    var importDomain: String {
        "\(importSlug).\(tld)"
    }

    private var hasOverlay: Bool {
        model.installing || model.finished || model.error != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if !hasOverlay { modeSwitcher }
            if hasOverlay {
                SiteInstallProgressView(events: model.events, error: model.error)
                    .padding(22)
                    .frame(maxHeight: 360)
            } else {
                ScrollView { activeForm.padding(.horizontal, 24).padding(.vertical, 18) }
                    .frame(maxHeight: 440)
            }
            footer
        }
        .onAppear {
            serveHTTPS = defaultHTTPS
            phpVersion = availableVersions.contains(defaultPHPVersion)
                ? defaultPHPVersion
                : (availableVersions.first ?? defaultPHPVersion)
        }
        .onChange(of: kind) { newKind in createDatabase = newKind != .empty }
    }

    private var modeSwitcher: some View {
        HStack {
            KTSegmentedTabs(items: [
                KTSegmentedTabs.Item(value: .create, label: "Create New"),
                KTSegmentedTabs.Item(value: .importFolder, label: "Import Folder"),
                KTSegmentedTabs.Item(value: .proxy, label: "Proxy"),
            ], selection: $mode, large: true)
            Spacer()
        }
        .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 2)
    }

    @ViewBuilder
    private var activeForm: some View {
        switch mode {
        case .create:
            createForm
        case .importFolder:
            ImportFolderForm(
                folder: $importFolder,
                name: $importName,
                phpVersion: $phpVersion,
                serveHTTPS: $serveHTTPS,
                createDatabase: $createDatabase,
                availableVersions: availableVersions,
                provisioning: provisioning,
                tld: tld
            )
        case .proxy:
            proxyForm
        }
    }

    @ViewBuilder
    var footer: some View {
        switch mode {
        case .importFolder: importFooter
        case .proxy: proxyFooter
        case .create: createFooter
        }
    }

    var proxyTargetError: String? {
        let trimmed = proxyTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if case let .failure(error) = ProxyTarget.parse(trimmed) { return error.localizedDescription }
        return nil
    }

    var proxyValid: Bool {
        guard !slug.isEmpty else { return false }
        if case .success = ProxyTarget.parse(proxyTarget.trimmingCharacters(in: .whitespacesAndNewlines)) { return true }
        return false
    }

    func addProxy() {
        model.addProxy(
            name: slug,
            domain: domain,
            target: proxyTarget.trimmingCharacters(in: .whitespacesAndNewlines),
            enableHTTPS: serveHTTPS,
            openOnFinish: true
        )
    }

    func create() {
        let request = NewSiteRequest(
            name: slug, kind: kind, phpVersion: phpVersion,
            folder: sitesRoot.appendingPathComponent(slug, isDirectory: true),
            domain: domain, databaseName: createDatabase ? slug : nil,
            siteTitle: slug, adminUser: "admin", adminEmail: "admin@example.com",
            adminPassword: kind == .wordpress ? adminPassword : ""
        )
        model.install(request: request, openOnFinish: true, enableHTTPS: serveHTTPS)
    }

    func importSite() {
        guard let importFolder else { return }
        model.importExisting(
            folder: importFolder,
            domain: importDomain,
            phpVersion: phpVersion,
            createDatabase: createDatabase,
            enableHTTPS: serveHTTPS,
            openOnFinish: true
        )
    }

    static func randomPassword() -> String {
        let chars = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<16).map { _ in chars.randomElement()! })
    }
}
