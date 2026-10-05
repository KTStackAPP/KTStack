import AppKit
import SwiftUI

struct FolderBrowsing: Identifiable {
    let id = UUID()
    let client: any BackupDestinationClient
}

extension DestinationEditor {
    static let defaultS3 = S3Settings(preset: .aws, endpoint: S3Preset.aws.endpoint(region: S3Preset.aws.defaultRegion),
                                      region: S3Preset.aws.defaultRegion, bucket: "", prefix: "", accessKeyID: "", usePathStyle: false)

    static func blank(_ kind: BackupDestinationKind) -> BackupDestination {
        switch kind {
        case .local: BackupDestination(name: "Backup Folder", kind: .local, local: LocalFolderSettings(path: ""))
        case .s3: BackupDestination(name: "S3 Bucket", kind: .s3, s3: defaultS3)
        case .googleDrive: BackupDestination(name: "Google Drive", kind: .googleDrive, googleDrive: GoogleDriveSettings())
        }
    }

    var validationMessage: String? {
        if destination.name.trimmingCharacters(in: .whitespaces).isEmpty { return "Give the destination a name." }
        switch destination.kind {
        case .local:
            return (destination.local?.path ?? "").isEmpty ? "Choose a folder." : nil
        case .s3:
            let settings = s3Settings.wrappedValue
            let required = [settings.endpoint, settings.region, settings.bucket, settings.accessKeyID]
            if required.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                return "Fill in the endpoint, region, bucket and access key ID."
            }
            return s3Secret.isEmpty && !model.hasSecret(.s3SecretAccessKey, for: destination.id) ? "Enter the secret access key." : nil
        case .googleDrive:
            if !googleConnected { return "Sign in with Google first." }
            return (destination.googleDrive?.folderID ?? "").isEmpty ? "Choose a Google Drive folder." : nil
        }
    }

    @ViewBuilder
    var localSections: some View {
        let path = destination.local?.path ?? ""
        Section {
            LabeledContent("Folder") {
                Text(path.isEmpty ? "Not chosen" : path).lineLimit(2).truncationMode(.middle)
            }
            Button("Choose Folder…", action: chooseLocalFolder)
        } header: {
            Text("Folder")
        } footer: {
            Text("An external drive, a network share or a synced folder such as iCloud Drive or Dropbox. Each plan gets its own subfolder.")
        }
    }

    @ViewBuilder
    var s3Sections: some View {
        Section("Provider") {
            Picker("Provider", selection: presetBinding) {
                ForEach(S3Preset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            TextField("Endpoint", text: s3Settings.endpoint, prompt: Text(s3Settings.wrappedValue.preset.endpointHint))
            TextField("Region", text: regionBinding)
            Toggle("Path-style requests", isOn: s3Settings.usePathStyle)
        }
        Section("Bucket") {
            TextField("Bucket", text: s3Settings.bucket)
            HStack {
                TextField("Folder", text: s3Settings.prefix, prompt: Text("optional"))
                Button("Browse…", action: browse).disabled(busy)
            }
        }
        Section {
            TextField("Access key ID", text: s3Settings.accessKeyID)
            SecureField("Secret access key", text: $s3Secret, prompt: Text(secretPrompt))
        } header: {
            Text("Credentials")
        } footer: {
            Text("The secret is kept in the macOS Keychain, never in KTStack's files or backups. A key limited to this bucket is enough.")
        }
    }

    func browse() {
        error = nil
        do {
            browsing = FolderBrowsing(client: try draftClient())
        } catch {
            self.error = error.localizedDescription
        }
    }

    @ViewBuilder
    func browserSheet(_ browsing: FolderBrowsing) -> some View {
        RemoteFolderBrowser(
            title: destination.kind == .s3 ? "Choose a Folder in the Bucket" : "Choose a Google Drive Folder",
            rootName: destination.kind == .s3 ? (s3Settings.wrappedValue.bucket) : "My Drive",
            client: browsing.client,
            onChoose: applyFolder,
            onCancel: { self.browsing = nil }
        )
    }

    private func applyFolder(_ path: [RemoteFolder]) {
        browsing = nil
        switch destination.kind {
        case .s3:
            destination.s3?.prefix = (path.last?.id ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        case .googleDrive:
            var drive = destination.googleDrive ?? GoogleDriveSettings()
            drive.folderID = path.last?.id ?? "root"
            drive.folderName = path.isEmpty ? "My Drive" : path.map(\.name).joined(separator: " / ")
            destination.googleDrive = drive
        case .local:
            break
        }
    }

    private func chooseLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose where KTStack stores backups."
        if let path = destination.local?.path, !path.isEmpty { panel.directoryURL = URL(fileURLWithPath: path) }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        destination.local = LocalFolderSettings(path: url.path)
        if isNew, destination.name == Self.blank(.local).name { destination.name = url.lastPathComponent }
    }

    private var secretPrompt: String {
        model.hasSecret(.s3SecretAccessKey, for: destination.id) ? "Saved — leave blank to keep" : "Required"
    }

    private var s3Settings: Binding<S3Settings> {
        Binding(get: { destination.s3 ?? Self.defaultS3 }, set: { destination.s3 = $0 })
    }

    private var presetBinding: Binding<S3Preset> {
        Binding(
            get: { s3Settings.wrappedValue.preset },
            set: { preset in
                var settings = s3Settings.wrappedValue
                settings.preset = preset
                settings.region = preset.defaultRegion
                settings.endpoint = preset.endpoint(region: preset.defaultRegion)
                settings.usePathStyle = preset.usesPathStyle
                destination.s3 = settings
            }
        )
    }

    private var regionBinding: Binding<String> {
        Binding(
            get: { s3Settings.wrappedValue.region },
            set: { region in
                var settings = s3Settings.wrappedValue
                if settings.endpoint == settings.preset.endpoint(region: settings.region) {
                    settings.endpoint = settings.preset.endpoint(region: region)
                }
                settings.region = region
                destination.s3 = settings
            }
        )
    }
}
