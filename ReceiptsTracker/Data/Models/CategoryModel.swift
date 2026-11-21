import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: String
    var name: String
    var iconId: String

    @Relationship(deleteRule: .nullify, inverse: \Receipt.category)
    var receipts: [Receipt] = []

    init(id: String, name: String, iconId: String) {
        self.id = id
        self.name = name
        self.iconId = iconId
    }

    static let defaultSeedDefinitions: [(id: String, name: String, iconId: String)] = [
        ("cat_groceries", "Groceries", "shopping_cart"),
        ("cat_dining", "Dining Out", "restaurant"),
        ("cat_transport", "Transport", "bus"),
        ("cat_tech", "Electronics", "tech"),
        ("cat_health", "Health", "health"),
        ("cat_utilities", "Bills & Utils", "utilities"),
        ("cat_shopping", "Shopping", "gift")
    ]
}
