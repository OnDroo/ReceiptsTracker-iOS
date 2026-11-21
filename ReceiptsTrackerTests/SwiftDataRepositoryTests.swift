import SwiftData
import XCTest
@testable import ReceiptsTracker

@MainActor
final class SwiftDataRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataReceiptRepository!

    override func setUp() async throws {
        container = try PersistenceController.makeModelContainer(inMemory: true)
        repository = SwiftDataReceiptRepository(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        repository = nil
        container = nil
    }

    func testDefaultCategoriesSeededIdempotently() throws {
        let categories = try repository.fetchAllCategories()
        XCTAssertEqual(categories.count, 7)

        let ids = Set(categories.map(\.id))
        XCTAssertTrue(ids.contains("cat_groceries"))
        XCTAssertTrue(ids.contains("cat_dining"))
        XCTAssertTrue(ids.contains("cat_transport"))
        XCTAssertTrue(ids.contains("cat_tech"))
        XCTAssertTrue(ids.contains("cat_health"))
        XCTAssertTrue(ids.contains("cat_utilities"))
        XCTAssertTrue(ids.contains("cat_shopping"))

        // Calling seed again should not duplicate categories
        PersistenceController.seedDefaultCategoriesIfNeeded(in: container.mainContext)
        XCTAssertEqual(try repository.fetchAllCategories().count, 7)
    }

    func testSaveFetchUpdateAndDeleteReceipt() throws {
        let categories = try repository.fetchAllCategories()
        let groceries = try XCTUnwrap(categories.first { $0.id == "cat_groceries" })
        let dining = try XCTUnwrap(categories.first { $0.id == "cat_dining" })

        let initial = ReceiptSnapshot(
            id: "rec-100",
            storeName: "Lidl",
            totalAmount: 19.34,
            dateTimestamp: Date(timeIntervalSince1970: 1_765_472_400),
            currency: "EUR",
            imageFileName: "rec-100.jpg",
            metadata: ReceiptMetadataSnapshot(paymentMethod: "Card", transactionId: "TX-1"),
            category: groceries,
            items: [
                ReceiptItemSnapshot(id: "item-1", name: "MullerMix Cr.Balls", quantity: 2, unit: "ks", price: 1.98),
                ReceiptItemSnapshot(id: "item-2", name: "Bread", quantity: 1, unit: "ks", price: 2.50)
            ]
        )

        try repository.saveReceipt(initial)

        let fetched = try XCTUnwrap(repository.fetchReceipt(id: "rec-100"))
        XCTAssertEqual(fetched.storeName, "Lidl")
        XCTAssertEqual(fetched.category?.id, "cat_groceries")
        XCTAssertEqual(fetched.items.count, 2)
        XCTAssertEqual(fetched.metadata.paymentMethod, "Card")

        // Update store name, category, edit one item, remove one, add a new one
        let updated = ReceiptSnapshot(
            id: "rec-100",
            storeName: "Lidl Market",
            totalAmount: 10.00,
            dateTimestamp: initial.dateTimestamp,
            currency: "EUR",
            imageFileName: "rec-100.jpg",
            metadata: ReceiptMetadataSnapshot(paymentMethod: "Apple Pay", transactionId: "TX-2"),
            category: dining,
            items: [
                ReceiptItemSnapshot(id: "item-1", name: "MullerMix Edited", quantity: 3, unit: "ks", price: 3.00),
                ReceiptItemSnapshot(id: "item-3", name: "Coffee", quantity: 1, unit: "pcs", price: 7.00)
            ]
        )

        try repository.updateReceipt(updated)

        let afterUpdate = try XCTUnwrap(repository.fetchReceipt(id: "rec-100"))
        XCTAssertEqual(afterUpdate.storeName, "Lidl Market")
        XCTAssertEqual(afterUpdate.totalAmount, 10.00, accuracy: 0.001)
        XCTAssertEqual(afterUpdate.category?.id, "cat_dining")
        XCTAssertEqual(afterUpdate.items.count, 2)
        XCTAssertEqual(Set(afterUpdate.items.map(\.name)), Set(["MullerMix Edited", "Coffee"]))

        try repository.deleteReceipt(id: "rec-100")
        XCTAssertNil(try repository.fetchReceipt(id: "rec-100"))
        XCTAssertTrue(try repository.fetchAllReceipts().isEmpty)
    }
}
