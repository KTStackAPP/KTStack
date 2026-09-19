import KTPluginKit
import SwiftUI

struct KTConnectEngineSelector: View {
    @Binding var kind: DatabaseKind
    let onSelectEngine: (DatabaseKind) -> Void

    private static let engines: [DatabaseKind] = [.mysql, .postgres, .sqlite, .mongodb]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(Self.engines, id: \.self) { engine in
                KTEngineCard(
                    name: engineDisplay(engine),
                    tint: KTEngineTint.of(engine.rawValue),
                    active: kind == engine
                ) {
                    kind = engine
                    onSelectEngine(engine)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func engineDisplay(_ kind: DatabaseKind) -> String {
        switch kind {
        case .mysql: "MySQL"
        case .postgres: "PostgreSQL"
        case .sqlite: "SQLite"
        case .mongodb: "MongoDB"
        }
    }
}
