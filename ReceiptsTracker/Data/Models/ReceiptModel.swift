import Foundation
import SwiftData

@Model
final class Receipt {
    @Attribute(.unique) var id: String
    var storeName: String
    var totalAmount: Double
    var dateTimestamp: Date
    var currency: String
    var imageFileName: String
    var paymentMethod: String?
    var transactionId: String?

    var category: Category?

    @Relationship(deleteRule: .cascade, inverse: \ReceiptItem.receipt)
    var items: [ReceiptItem] = []

    init(
        id: String,
        storeName: String,
        totalAmount: Double,
        dateTimestamp: Date,
        currency: String,
        imageFileName: String,
        paymentMethod: String? = nil,
        transactionId: String? = nil,
        category: Category? = nil
    ) {
        self.id = id
        self.storeName = storeName
        self.totalAmount = totalAmount
        self.dateTimestamp = dateTimestamp
        self.currency = currency
        self.imageFileName = imageFileName
        self.paymentMethod = paymentMethod
        self.transactionId = transactionId
        self.category = category
    }
}
