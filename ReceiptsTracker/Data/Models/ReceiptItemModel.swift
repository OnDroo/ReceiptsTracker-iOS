import Foundation
import SwiftData

@Model
final class ReceiptItem {
    @Attribute(.unique) var id: String
    var name: String
    var quantity: Double
    var unit: String?
    var price: Double

    var receipt: Receipt?

    init(
        id: String = UUID().uuidString,
        name: String,
        quantity: Double,
        unit: String? = nil,
        price: Double,
        receipt: Receipt? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.price = price
        self.receipt = receipt
    }
}
