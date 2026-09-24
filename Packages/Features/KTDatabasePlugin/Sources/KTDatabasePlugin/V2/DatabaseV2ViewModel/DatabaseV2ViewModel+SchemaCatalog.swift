import Combine
import Foundation

final class SchemaCatalogCache {
    private var value: SchemaCatalog = .empty
    private var subscription: AnyCancellable?

    @MainActor
    func catalog(of model: DatabaseV2ViewModel) -> SchemaCatalog {
        if subscription == nil {
            subscription = Publishers.CombineLatest3(model.$tables, model.$diagramColumns, model.$foreignKeys)
                .sink { [weak self] tables, columns, relations in
                    self?.value = SchemaCatalog(
                        tables: tables.map(\.name),
                        columnsByTable: columns.mapValues { $0.map(\.name) },
                        detailedColumnsByTable: columns,
                        relations: relations
                    )
                }
        }
        return value
    }
}

public extension DatabaseV2ViewModel {
    var schemaCatalog: SchemaCatalog {
        catalogCache.catalog(of: self)
    }
}
