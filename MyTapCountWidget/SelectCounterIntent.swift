import AppIntents

/// small ウィジェットで表示する項目。ウィジェットを長押し →「ウィジェットを編集」で選ぶ。
struct SelectCounterIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "widget.config.title"
    static var description = IntentDescription("widget.config.description")

    @Parameter(title: "widget.config.counter")
    var counter: CounterEntity?

    init() {}
}

struct CounterEntity: AppEntity {
    let id: UUID
    let name: String
    let symbol: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "widget.entity.counter")
    static var defaultQuery = CounterEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }
}

struct CounterEntityQuery: EntityQuery {
    func entities(for identifiers: [CounterEntity.ID]) async throws -> [CounterEntity] {
        let wanted = Set(identifiers)
        return all().filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CounterEntity] {
        all()
    }

    private func all() -> [CounterEntity] {
        WidgetData.snapshots().map { CounterEntity(id: $0.id, name: $0.name, symbol: $0.symbol) }
    }
}
