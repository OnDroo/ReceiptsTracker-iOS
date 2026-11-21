import SwiftData
import XCTest
@testable import ReceiptsTracker

private final class TestSecretStorage: SecretStorageProtocol, @unchecked Sendable {
    func save(_ value: String, forKey key: String) {}
    func load(forKey key: String) -> String? { nil }
    func delete(forKey key: String) {}
}

@MainActor
final class ViewModelsTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataReceiptRepository!
    private var settingsStore: SettingsStore!
    private var suiteName: String!

    override func setUp() async throws {
        container = try PersistenceController.makeModelContainer(inMemory: true)
        repository = SwiftDataReceiptRepository(modelContext: container.mainContext)
        suiteName = "ViewModelsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        settingsStore = SettingsStore(secretStorage: TestSecretStorage(), userDefaults: defaults)
        settingsStore.currency = "EUR"
    }

    override func tearDown() async throws {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        settingsStore = nil
        repository = nil
        container = nil
    }

    func testDashboardGroupsSmallCategoriesIntoOthersAndConvertsCurrency() throws {
        let categories = try repository.fetchAllCategories()
        let groceries = try XCTUnwrap(categories.first { $0.id == "cat_groceries" })
        let dining = try XCTUnwrap(categories.first { $0.id == "cat_dining" })
        let health = try XCTUnwrap(categories.first { $0.id == "cat_health" })

        let fixedNow = DateUtils.parseGeminiDate("2026-06-10 12:00:00")

        // Groceries: 100 EUR
        try repository.saveReceipt(ReceiptSnapshot(
            id: "r1",
            storeName: "Lidl",
            totalAmount: 100.0,
            dateTimestamp: fixedNow,
            currency: "EUR",
            imageFileName: "r1.jpg",
            category: groceries,
            items: []
        ))

        // Dining: 100 USD -> 92 EUR
        try repository.saveReceipt(ReceiptSnapshot(
            id: "r2",
            storeName: "Cafe",
            totalAmount: 100.0,
            dateTimestamp: fixedNow,
            currency: "USD",
            imageFileName: "r2.jpg",
            category: dining,
            items: []
        ))

        // Health: 5 EUR (< 7% of 197 EUR -> should fold into "Others")
        try repository.saveReceipt(ReceiptSnapshot(
            id: "r3",
            storeName: "Pharmacy",
            totalAmount: 5.0,
            dateTimestamp: fixedNow,
            currency: "EUR",
            imageFileName: "r3.jpg",
            category: health,
            items: []
        ))

        let vm = DashboardViewModel(
            repository: repository,
            settingsStore: settingsStore,
            nowProvider: { fixedNow }
        )
        vm.selectedFilter = .allTime
        vm.reload()

        XCTAssertEqual(vm.receiptCount, 3)
        XCTAssertEqual(vm.categoryBreakdown.map(\.name), ["Groceries", "Dining Out", "Others"])
    }

    func testReceiptListSearchMatchesStoreAndLineItems() throws {
        let categories = try repository.fetchAllCategories()
        let groceries = try XCTUnwrap(categories.first { $0.id == "cat_groceries" })
        let tech = try XCTUnwrap(categories.first { $0.id == "cat_tech" })

        try repository.saveReceipt(ReceiptSnapshot(
            id: "r-lidl",
            storeName: "Lidl",
            totalAmount: 19.34,
            dateTimestamp: DateUtils.parseGeminiDate("2026-01-22 17:59:00"),
            currency: "EUR",
            imageFileName: "r-lidl.jpg",
            category: groceries,
            items: [
                ReceiptItemSnapshot(id: "it-1", name: "MullerMix Cr.Balls", quantity: 2, unit: "ks", price: 1.98)
            ]
        ))

        try repository.saveReceipt(ReceiptSnapshot(
            id: "r-alza",
            storeName: "Alza",
            totalAmount: 1200.0,
            dateTimestamp: DateUtils.parseGeminiDate("2025-12-11 10:00:00"),
            currency: "CZK",
            imageFileName: "r-alza.jpg",
            category: tech,
            items: [
                ReceiptItemSnapshot(id: "it-2", name: "USB-C Cable", quantity: 1, unit: "ks", price: 1200.0)
            ]
        ))

        let vm = ReceiptListViewModel(repository: repository)
        vm.reload()
        XCTAssertEqual(vm.totalResultsCount, 2)
        XCTAssertEqual(vm.sections.count, 2)

        // Search by line item name
        vm.searchQuery = "Muller"
        XCTAssertEqual(vm.totalResultsCount, 1)
        let matchedRow = try XCTUnwrap(vm.sections.first?.items.first)
        XCTAssertEqual(matchedRow.storeName, "Lidl")
        XCTAssertEqual(matchedRow.matchedItems, ["MullerMix Cr.Balls (2x)"])

        // Filter by category
        vm.searchQuery = ""
        vm.toggleCategory("cat_tech")
        XCTAssertEqual(vm.totalResultsCount, 1)
        XCTAssertEqual(vm.sections.first?.items.first?.storeName, "Alza")

        // Toggling same category clears filter
        vm.toggleCategory("cat_tech")
        XCTAssertEqual(vm.totalResultsCount, 2)
    }
}
