import SwiftUI

extension DestinationEditor {
    @ViewBuilder
    var googleSections: some View {
        Section {
            if googleConnected {
                LabeledContent("Signed in as") {
                    Text(drive.accountEmail.isEmpty ? "Google account" : drive.accountEmail)
                }
                Button("Disconnect", action: disconnectGoogle).disabled(busy)
            } else {
                Button("Sign in with Google…", action: connectGoogle).disabled(busy || !canSignIn)
            }
        } header: {
            Text("Account")
        } footer: {
            Text(accountFooter)
        }
        Section {
            LabeledContent("Folder") {
                Text(drive.folderID.isEmpty ? "Not chosen" : drive.folderName)
            }
            HStack {
                Button("Browse…", action: browse)
                if model.pickerAvailable {
                    Button("Pick Existing Folder…", action: pickGoogleFolder)
                }
            }
            .disabled(!googleConnected || busy)
        } header: {
            Text("Folder")
        } footer: {
            Text(folderFooter)
        }
        Section {
            TextField("Client ID", text: customClientIDBinding, prompt: Text("optional"))
            if !(drive.customClientID ?? "").isEmpty {
                SecureField("Client secret", text: $googleClientSecret,
                            prompt: Text(model.hasSecret(.googleClientSecret, for: destination.id) ? "Saved — leave blank to keep" : ""))
            }
        } header: {
            Text("Own OAuth Client")
        } footer: {
            Text("Leave empty to use KTStack's Google app. To use your own, create a Desktop app OAuth client with the Google Drive API enabled.")
        }
    }

    private var drive: GoogleDriveSettings {
        destination.googleDrive ?? GoogleDriveSettings()
    }

    private var canSignIn: Bool {
        model.googleAvailable || !(drive.customClientID ?? "").isEmpty
    }

    private var accountFooter: String {
        guard canSignIn else {
            return "This copy of KTStack has no Google app configured. Enter your own OAuth client below to connect."
        }
        return "Your browser opens to sign in. KTStack only gets access to files it creates or that you pick, "
            + "and keeps the sign-in token in the macOS Keychain."
    }

    private var folderFooter: String {
        let base = "Browse shows folders KTStack created and lets you create a new one."
        return model.pickerAvailable ? base + " Pick Existing Folder opens Google's picker for any folder in your Drive." : base
    }

    private var customClientIDBinding: Binding<String> {
        Binding(
            get: { drive.customClientID ?? "" },
            set: { value in
                var settings = drive
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                settings.customClientID = trimmed.isEmpty ? nil : trimmed
                destination.googleDrive = settings
            }
        )
    }

    private func connectGoogle() {
        let snapshot = destination
        let clientSecret = googleClientSecret
        run {
            if !(snapshot.googleDrive?.customClientID ?? "").isEmpty, !clientSecret.isEmpty {
                try model.services.secrets.setSecret(clientSecret, .googleClientSecret, for: snapshot.id)
            }
            let email = try await model.connectGoogle(snapshot)
            var settings = destination.googleDrive ?? GoogleDriveSettings()
            settings.accountEmail = email
            destination.googleDrive = settings
            googleConnected = true
        }
    }

    private func disconnectGoogle() {
        let snapshot = destination
        run {
            await model.disconnectGoogle(snapshot)
            destination.googleDrive?.accountEmail = ""
            googleConnected = false
        }
    }

    private func pickGoogleFolder() {
        let snapshot = destination
        run {
            guard let folder = try await model.pickGoogleFolder(snapshot) else { return }
            var settings = destination.googleDrive ?? GoogleDriveSettings()
            settings.folderID = folder.id
            settings.folderName = folder.name
            destination.googleDrive = settings
        }
    }
}
