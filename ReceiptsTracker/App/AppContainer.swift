import Foundation
import Observation
import SwiftData
import UIKit

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
        makeDemo()
    }

    static func makeDemo() -> AppContainer {
        let demoDir = FileManager.default.temporaryDirectory.appendingPathComponent("ReceiptsDemoImages", isDirectory: true)
        let storage = FileStorageHelper(baseDirectory: demoDir)
        let suiteName = "ReceiptsTrackerDemo-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let secrets = InMemorySecretStorage()
        secrets.save("demo-preview-key-not-real", forKey: SettingsStore.Keys.apiKey)

        let container = AppContainer(
            inMemory: true,
            secretStorage: secrets,
            userDefaults: defaults,
            fileStorage: storage
        )
        let categories = (try? container.receiptRepository.fetchAllCategories()) ?? []
        let groceries = categories.first { $0.id == "cat_groceries" }
        let dining = categories.first { $0.id == "cat_dining" }
        let tech = categories.first { $0.id == "cat_tech" }
        let transport = categories.first { $0.id == "cat_transport" }

        let now = Date()
        let samples: [ReceiptSnapshot] = [
            ReceiptSnapshot(
                id: "demo-1",
                storeName: "Lidl",
                totalAmount: 42.85,
                dateTimestamp: now.addingTimeInterval(-3600 * 5),
                currency: "EUR",
                imageFileName: "demo-1.jpg",
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
                id: "demo-2",
                storeName: "Alza",
                totalAmount: 1890.00,
                dateTimestamp: now.addingTimeInterval(-86400 * 2),
                currency: "CZK",
                imageFileName: "demo-2.jpg",
                metadata: ReceiptMetadataSnapshot(paymentMethod: "Card", transactionId: "ALZ-5510"),
                category: tech,
                items: [
                    ReceiptItemSnapshot(id: "i5", name: "USB-C Braided Cable", quantity: 2, unit: "pcs", price: 690.00),
                    ReceiptItemSnapshot(id: "i6", name: "MagSafe Stand", quantity: 1, unit: "pcs", price: 1200.00)
                ]
            ),
            ReceiptSnapshot(
                id: "demo-3",
                storeName: "Blue Bottle Coffee",
                totalAmount: 14.50,
                dateTimestamp: now.addingTimeInterval(-86400 * 3),
                currency: "USD",
                imageFileName: "demo-3.jpg",
                metadata: ReceiptMetadataSnapshot(paymentMethod: "Apple Pay", transactionId: nil),
                category: dining,
                items: [
                    ReceiptItemSnapshot(id: "i7", name: "Flat White", quantity: 2, unit: "x", price: 10.50),
                    ReceiptItemSnapshot(id: "i8", name: "Croissant", quantity: 1, unit: "x", price: 4.00)
                ]
            ),
            ReceiptSnapshot(
                id: "demo-4",
                storeName: "City Metro Pass",
                totalAmount: 29.00,
                dateTimestamp: now.addingTimeInterval(-86400 * 5),
                currency: "EUR",
                imageFileName: "demo-4.jpg",
                metadata: ReceiptMetadataSnapshot(paymentMethod: "Apple Pay", transactionId: "MTR-2041"),
                category: transport,
                items: [
                    ReceiptItemSnapshot(id: "i9", name: "Weekly Transit Pass", quantity: 1, unit: "pcs", price: 29.00)
                ]
            )
        ]

        for receipt in samples {
            let rendered = renderMockReceiptImage(for: receipt)
            _ = try? storage.saveJPEGImage(rendered, compressionQuality: 0.85, id: receipt.id)
            try? container.receiptRepository.saveReceipt(receipt)
        }
        return container
    }

    private static func renderMockReceiptImage(for receipt: ReceiptSnapshot) -> UIImage {
        let size = CGSize(width: 600, height: 920)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(white: 0.98, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 34, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 22, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let boldAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 26, weight: .bold),
                .foregroundColor: UIColor.black
            ]

            receipt.storeName.uppercased().draw(at: CGPoint(x: 44, y: 56), withAttributes: titleAttrs)
            DateUtils.formatDetailDateTime(receipt.dateTimestamp).draw(at: CGPoint(x: 44, y: 112), withAttributes: bodyAttrs)

            "----------------------------------------".draw(at: CGPoint(x: 44, y: 164), withAttributes: bodyAttrs)

            var y: CGFloat = 212
            for item in receipt.items {
                let line = "\(Int(max(1, item.quantity)))x \(item.name)"
                let price = String(format: "%.2f %@", item.price, receipt.currency)
                line.draw(at: CGPoint(x: 44, y: y), withAttributes: bodyAttrs)
                price.draw(at: CGPoint(x: 410, y: y), withAttributes: bodyAttrs)
                y += 46
            }

            "----------------------------------------".draw(at: CGPoint(x: 44, y: y + 20), withAttributes: bodyAttrs)
            "TOTAL".draw(at: CGPoint(x: 44, y: y + 72), withAttributes: boldAttrs)
            String(format: "%.2f %@", receipt.totalAmount, receipt.currency)
                .draw(at: CGPoint(x: 380, y: y + 72), withAttributes: boldAttrs)

            // Barcode stripes at bottom
            UIColor.black.setFill()
            let barcodeY = size.height - 140
            for i in 0..<36 {
                let barWidth: CGFloat = (i % 3 == 0) ? 7 : 3
                let x = 80 + CGFloat(i) * 12
                ctx.fill(CGRect(x: x, y: barcodeY, width: barWidth, height: 74))
            }
        }
    }
}

private final class InMemorySecretStorage: SecretStorageProtocol, @unchecked Sendable {
    private var values: [String: String] = [:]
    func save(_ value: String, forKey key: String) { values[key] = value }
    func load(forKey key: String) -> String? { values[key] }
    func delete(forKey key: String) { values.removeValue(forKey: key) }
}
