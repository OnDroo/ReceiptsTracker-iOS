import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppContainer {
    let modelContainer: ModelContainer
    let receiptRepository: ReceiptRepositoryProtocol
    let settingsStore: SettingsStore
    let geminiService: GeminiService
    let fileStorage: FileStorageHelper

    init(
        inMemory: Bool = false,
        secretStorage: SecretStorageProtocol = KeychainHelper.shared,
        userDefaults: UserDefaults = .standard,
        fileStorage: FileStorageHelper = .shared
    ) {
        let container: ModelContainer
        do {
            container = try PersistenceController.makeModelContainer(inMemory: inMemory)
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }

        self.modelContainer = container
        self.fileStorage = fileStorage

        let repository = SwiftDataReceiptRepository(modelContext: container.mainContext)
        self.receiptRepository = repository

        let settings = SettingsStore(secretStorage: secretStorage, userDefaults: userDefaults)
        self.settingsStore = settings

        self.geminiService = GeminiService(
            settingsStore: settings,
            receiptRepository: repository
        )
    }

    static var preview: AppContainer {
        let container = AppContainer(
            inMemory: true,
            secretStorage: InMemorySecretStorage(),
            userDefaults: UserDefaults(suiteName: "ReceiptsTrackerPreview") ?? .standard
        )
        let categories = (try? container.receiptRepository.fetchAllCategories()) ?? []
        let groceries = categories.first { $0.id == "cat_groceries" }
        let dining = categories.first { $0.id == "cat_dining" }
        let tech = categories.first { $0.id == "cat_tech" }

        let now = Date()
        let samples: [ReceiptSnapshot] = [
            ReceiptSnapshot(
                id: "preview-1",
                storeName: "Lidl",
                totalAmount: 42.85,
                dateTimestamp: now.addingTimeInterval(-3600 * 5),
                currency: "EUR",
                imageFileName: "",
                metadata: ReceiptMetadataSnapshot(paymentMethod: "Apple Pay", transactionId: "TX-89412"),
                category: groceries,
                items: [
                    ReceiptItemSnapshot(id: "i1", name: "Organic Milk", quantity: 2, unit: "pcs", price: 3.40),
                    ReceiptItemSnapshot(id: "i2", name: "Sourdough Bread", quantity: 1, unit: "pcs", price: 2.95),
                    ReceiptItemSnapshot(id: "i3", name: "Fresh Vegetables", quantity: 1.5, unit: "kg", price: 11.50),
                    ReceiptItemSnapshot(id: "i4", name: "Coffee Beans", quantity: 1, unit: "kg", price: 25.00)
                ]
            ),
            ReceiptSnapshot(
                id: "preview-2",
                storeName: "Alza",
                totalAmount: 1890.00,
                dateTimestamp: now.addingTimeInterval(-86400 * 2),
                currency: "CZK",
                imageFileName: "",
                metadata: ReceiptMetadataSnapshot(paymentMethod: "Card", transactionId: "ALZ-5510"),
                category: tech,
                items: [
                    ReceiptItemSnapshot(id: "i5", name: "USB-C Braided Cable", quantity: 2, unit: "pcs", price: 690.00),
                    ReceiptItemSnapshot(id: "i6", name: "MagSafe Stand", quantity: 1, unit: "pcs", price: 1200.00)
                ]
            ),
            ReceiptSnapshot(
                id: "preview-3",
                storeName: "Blue Bottle Coffee",
                totalAmount: 14.50,
                dateTimestamp: now.addingTimeInterval(-86400 * 3),
                currency: "USD",
                imageFileName: "",
                metadata: ReceiptMetadataSnapshot(paymentMethod: "Apple Pay", transactionId: nil),
                category: dining,
                items: [
                    ReceiptItemSnapshot(id: "i7", name: "Flat White", quantity: 2, unit: "x", price: 10.50),
                    ReceiptItemSnapshot(id: "i8", name: "Croissant", quantity: 1, unit: "x", price: 4.00)
                ]
            )
        ]

        for receipt in samples {
            try? container.receiptRepository.saveReceipt(receipt)
        }
        return container
    }
}

private final class InMemorySecretStorage: SecretStorageProtocol, @unchecked Sendable {
    private var values: [String: String] = [:]
    func save(_ value: String, forKey key: String) { values[key] = value }
    func load(forKey key: String) -> String? { values[key] }
    func delete(forKey key: String) { values.removeValue(forKey: key) }
}
