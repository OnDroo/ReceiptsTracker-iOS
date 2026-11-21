import Foundation
import SwiftData

@MainActor
final class SwiftDataReceiptRepository: ReceiptRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllReceipts() throws -> [ReceiptSnapshot] {
        let descriptor = FetchDescriptor<Receipt>(
            sortBy: [SortDescriptor(\.dateTimestamp, order: .reverse)]
        )
        let receipts = try modelContext.fetch(descriptor)
        return receipts.map(ReceiptSnapshot.init(model:))
    }

    func fetchReceipt(id: String) throws -> ReceiptSnapshot? {
        let targetId = id
        var descriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate<Receipt> { $0.id == targetId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(ReceiptSnapshot.init(model:))
    }

    func saveReceipt(_ receipt: ReceiptSnapshot) throws {
        let categoryModel = try resolveCategory(id: receipt.category?.id)

        // Upsert by id to match Android OnConflictStrategy.REPLACE
        let targetId = receipt.id
        var existingDescriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate<Receipt> { $0.id == targetId }
        )
        existingDescriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(existingDescriptor).first {
            modelContext.delete(existing)
        }

        let newReceipt = Receipt(
            id: receipt.id,
            storeName: receipt.storeName,
            totalAmount: receipt.totalAmount,
            dateTimestamp: receipt.dateTimestamp,
            currency: receipt.currency,
            imageFileName: receipt.imageFileName,
            paymentMethod: receipt.metadata.paymentMethod,
            transactionId: receipt.metadata.transactionId,
            category: categoryModel
        )
        modelContext.insert(newReceipt)

        for item in receipt.items {
            let newItem = ReceiptItem(
                id: item.id,
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
                price: item.price,
                receipt: newReceipt
            )
            newReceipt.items.append(newItem)
            modelContext.insert(newItem)
        }

        try modelContext.save()
        NotificationCenter.default.post(name: .receiptsDidChange, object: nil)
    }

    func updateReceipt(_ receipt: ReceiptSnapshot) throws {
        let targetId = receipt.id
        var descriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate<Receipt> { $0.id == targetId }
        )
        descriptor.fetchLimit = 1

        guard let existing = try modelContext.fetch(descriptor).first else {
            try saveReceipt(receipt)
            return
        }

        existing.storeName = receipt.storeName
        existing.totalAmount = receipt.totalAmount
        existing.dateTimestamp = receipt.dateTimestamp
        existing.currency = receipt.currency
        existing.paymentMethod = receipt.metadata.paymentMethod
        existing.transactionId = receipt.metadata.transactionId
        existing.category = try resolveCategory(id: receipt.category?.id)

        // Diff items by id so existing SwiftData @Attribute(.unique) rows update cleanly in place
        let incomingById = Dictionary(uniqueKeysWithValues: receipt.items.map { ($0.id, $0) })
        let existingById = Dictionary(uniqueKeysWithValues: existing.items.map { ($0.id, $0) })

        for oldItem in existing.items where incomingById[oldItem.id] == nil {
            existing.items.removeAll { $0.id == oldItem.id }
            modelContext.delete(oldItem)
        }

        for item in receipt.items {
            if let current = existingById[item.id] {
                current.name = item.name
                current.quantity = item.quantity
                current.unit = item.unit
                current.price = item.price
            } else {
                let newItem = ReceiptItem(
                    id: item.id,
                    name: item.name,
                    quantity: item.quantity,
                    unit: item.unit,
                    price: item.price,
                    receipt: existing
                )
                existing.items.append(newItem)
                modelContext.insert(newItem)
            }
        }

        try modelContext.save()
        NotificationCenter.default.post(name: .receiptsDidChange, object: nil)
    }

    func deleteReceipt(id: String) throws {
        let targetId = id
        var descriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate<Receipt> { $0.id == targetId }
        )
        descriptor.fetchLimit = 1
        guard let existing = try modelContext.fetch(descriptor).first else { return }

        modelContext.delete(existing)
        try modelContext.save()
        NotificationCenter.default.post(name: .receiptsDidChange, object: nil)
    }

    func fetchAllCategories() throws -> [CategorySnapshot] {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(CategorySnapshot.init(model:))
    }

    private func resolveCategory(id: String?) throws -> Category? {
        guard let id else { return nil }
        let targetId = id
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { $0.id == targetId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
