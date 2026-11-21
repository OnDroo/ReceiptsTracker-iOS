import Foundation

struct CategorySnapshot: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var iconId: String

    init(id: String, name: String, iconId: String) {
        self.id = id
        self.name = name
        self.iconId = iconId
    }

    init(model: Category) {
        self.id = model.id
        self.name = model.name
        self.iconId = model.iconId
    }
}

struct ReceiptItemSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var quantity: Double
    var unit: String?
    var price: Double

    init(
        id: String = UUID().uuidString,
        name: String,
        quantity: Double = 1.0,
        unit: String? = nil,
        price: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.price = price
    }

    init(model: ReceiptItem) {
        self.id = model.id
        self.name = model.name
        self.quantity = model.quantity
        self.unit = model.unit
        self.price = model.price
    }
}

struct ReceiptMetadataSnapshot: Hashable, Sendable {
    var paymentMethod: String?
    var transactionId: String?

    var hasAnyValue: Bool {
        let hasPayment = !(paymentMethod?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasTx = !(transactionId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasPayment || hasTx
    }
}

struct ReceiptSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    var storeName: String
    var totalAmount: Double
    var dateTimestamp: Date
    var currency: String
    var imageFileName: String
    var metadata: ReceiptMetadataSnapshot
    var category: CategorySnapshot?
    var items: [ReceiptItemSnapshot]

    init(
        id: String,
        storeName: String,
        totalAmount: Double,
        dateTimestamp: Date,
        currency: String,
        imageFileName: String,
        metadata: ReceiptMetadataSnapshot = ReceiptMetadataSnapshot(paymentMethod: nil, transactionId: nil),
        category: CategorySnapshot? = nil,
        items: [ReceiptItemSnapshot] = []
    ) {
        self.id = id
        self.storeName = storeName
        self.totalAmount = totalAmount
        self.dateTimestamp = dateTimestamp
        self.currency = currency
        self.imageFileName = imageFileName
        self.metadata = metadata
        self.category = category
        self.items = items
    }

    init(model: Receipt) {
        self.id = model.id
        self.storeName = model.storeName
        self.totalAmount = model.totalAmount
        self.dateTimestamp = model.dateTimestamp
        self.currency = model.currency
        self.imageFileName = model.imageFileName
        self.metadata = ReceiptMetadataSnapshot(
            paymentMethod: model.paymentMethod,
            transactionId: model.transactionId
        )
        self.category = model.category.map(CategorySnapshot.init(model:))
        self.items = model.items
            .map(ReceiptItemSnapshot.init(model:))
            .sorted { $0.id < $1.id }
    }
}
