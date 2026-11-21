import Foundation
import SwiftData

@MainActor
enum PersistenceController {
    static let schema = Schema([
        Receipt.self,
        ReceiptItem.self,
        Category.self
    ])

    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        seedDefaultCategoriesIfNeeded(in: container.mainContext)
        return container
    }

    static func seedDefaultCategoriesIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for seed in Category.defaultSeedDefinitions {
            let category = Category(id: seed.id, name: seed.name, iconId: seed.iconId)
            context.insert(category)
        }
        try? context.save()
    }
}
