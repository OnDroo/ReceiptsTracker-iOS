import SwiftData
import XCTest
@testable import ReceiptsTracker

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class MockSecretStorage: SecretStorageProtocol, @unchecked Sendable {
    var store: [String: String] = [:]
    func save(_ value: String, forKey key: String) { store[key] = value }
    func load(forKey key: String) -> String? { store[key] }
    func delete(forKey key: String) { store.removeValue(forKey: key) }
}

final class GeminiServiceTests: XCTestCase {
    private var mockSession: URLSession!
    private var secretStorage: MockSecretStorage!
    private var userDefaults: UserDefaults!
    private var suiteName: String!
    private var modelContainer: ModelContainer?

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        secretStorage = MockSecretStorage()
        suiteName = "GeminiServiceTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        modelContainer = nil
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    @MainActor
    private func makeService(apiKey: String = "test-api-key") throws -> (GeminiService, SwiftDataReceiptRepository) {
        let container = try PersistenceController.makeModelContainer(inMemory: true)
        self.modelContainer = container
        let repository = SwiftDataReceiptRepository(modelContext: container.mainContext)
        let settings = SettingsStore(secretStorage: secretStorage, userDefaults: userDefaults)
        settings.apiKey = apiKey
        XCTAssertEqual(settings.selectedModel, "gemini-4-hydrogen")
        let service = GeminiService(
            settingsStore: settings,
            receiptRepository: repository,
            urlSession: mockSession
        )
        return (service, repository)
    }

    func testFetchAvailableModelsFiltersAndSortsHydrogenAndFlashFirst() async throws {
        let (service, _) = try await makeService()

        let json = """
        {
          "models": [
            { "name": "models/gemini-2.5-pro", "supportedGenerationMethods": ["generateContent"] },
            { "name": "models/gemini-2.0-flash", "supportedGenerationMethods": ["generateContent"] },
            { "name": "models/gemini-2.5-flash", "supportedGenerationMethods": ["generateContent"] },
            { "name": "models/gemini-4-hydrogen", "supportedGenerationMethods": ["generateContent"] },
            { "name": "models/embedding-001", "supportedGenerationMethods": ["embedContent"] },
            { "name": "models/gemini-1.0-ultra", "supportedGenerationMethods": ["generateContent"] }
          ]
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let models = await service.fetchAvailableModels(apiKey: "test-key")
        XCTAssertEqual(models, ["gemini-4-hydrogen", "gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.5-pro"])
    }

    func testAnalyzeReceiptParsesAndPersistsReceipt() async throws {
        let (service, repository) = try await makeService()

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("receipt-abc.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: imageURL)

        let innerReceiptJSON = """
        {
          "storeName": "McDonald's",
          "totalAmount": 320.0,
          "currency": "CZK",
          "date": "2026-01-08 17:27:00",
          "categoryName": "Dining Out",
          "items": [
            { "name": "CHEESE KING-MC", "quantity": 1.0, "unit": "KS", "price": 249.0 },
            { "name": "FRIES", "quantity": 1.0, "unit": "KS", "price": 71.0 }
          ],
          "metadata": {
            "paymentMethod": "Card",
            "transactionId": "MC-991"
          }
        }
        """

        let envelope: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [
                            ["text": innerReceiptJSON]
                        ]
                    ]
                ]
            ]
        ]
        let responseData = try JSONSerialization.data(withJSONObject: envelope)

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.absoluteString.contains("gemini-4-hydrogen:generateContent") == true)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseData)
        }

        let receiptId = try await service.analyzeReceipt(imageURL: imageURL)
        XCTAssertEqual(receiptId, "receipt-abc")

        let saved = try await MainActor.run { try repository.fetchReceipt(id: "receipt-abc") }
        let unwrapped = try XCTUnwrap(saved)
        XCTAssertEqual(unwrapped.storeName, "McDonald's")
        XCTAssertEqual(unwrapped.totalAmount, 320.0, accuracy: 0.001)
        XCTAssertEqual(unwrapped.currency, "CZK")
        XCTAssertEqual(unwrapped.category?.id, "cat_dining")
        XCTAssertEqual(unwrapped.items.count, 2)
        XCTAssertEqual(unwrapped.metadata.paymentMethod, "Card")
    }

    func testAnalyzeReceiptThrowsMissingApiKeyError() async throws {
        let (service, _) = try await makeService(apiKey: "")
        let dummyURL = URL(fileURLWithPath: "/tmp/nonexistent.jpg")

        do {
            _ = try await service.analyzeReceipt(imageURL: dummyURL)
            XCTFail("Expected missingApiKey error")
        } catch let error as GeminiServiceError {
            XCTAssertEqual(error, .missingApiKey)
            XCTAssertTrue(error.isApiKeyIssue)
        }
    }

    func testQuotaErrorProducesFriendlyMessage() {
        let error = GeminiServiceError.apiError(code: 429, message: "RESOURCE_EXHAUSTED: quota exceeded")
        XCTAssertFalse(error.isApiKeyIssue)
        XCTAssertTrue(error.friendlyMessage.contains("Quota Exceeded"))
        XCTAssertTrue(error.friendlyMessage.contains("Flash"))
    }
}
