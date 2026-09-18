import KTPluginKit
import SwiftUI

struct KTConnectServerFields: View {
    let kind: DatabaseKind
    @Binding var host: String
    @Binding var port: String
    @Binding var database: String
    @Binding var user: String
    @Binding var password: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                KTModalLabeledRow(label: "Host") {
                    KTModalField(placeholder: "127.0.0.1", text: $host, mono: true)
                }
                HStack(spacing: 10) {
                    Text("Port")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(nsColor: .labelColor))
                    KTModalField(placeholder: "3306", text: $port, mono: true)
                        .frame(width: 90)
                }
            }
            KTModalLabeledRow(label: "Database") {
                KTModalField(placeholder: "my_app", text: $database, mono: true)
            }
            HStack(spacing: 14) {
                KTModalLabeledRow(label: "Username") {
                    KTModalField(placeholder: usernamePlaceholder, text: $user, mono: true)
                }
                HStack(spacing: 10) {
                    Text("Password")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(nsColor: .labelColor))
                    KTModalField(placeholder: "••••••", text: $password, isSecure: true)
                }
            }
            if kind == .mysql || kind == .postgres {
                Text("Bundled \(engineDisplay(kind)) ships without a password: use “\(defaultUser(kind))” and leave Password blank.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
        }
    }

    private func engineDisplay(_ kind: DatabaseKind) -> String {
        switch kind {
        case .mysql: "MySQL"
        case .postgres: "PostgreSQL"
        case .sqlite: "SQLite"
        case .mongodb: "MongoDB"
        }
    }

    private func defaultUser(_ kind: DatabaseKind) -> String {
        switch kind {
        case .postgres: "postgres"
        case .mysql: "root"
        case .mongodb, .sqlite: ""
        }
    }

    private var usernamePlaceholder: String {
        switch kind {
        case .postgres: "postgres"
        case .mysql: "root"
        case .mongodb: "leave blank (no auth)"
        case .sqlite: "root"
        }
    }
}
