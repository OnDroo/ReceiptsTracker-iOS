import Foundation
import UIKit

enum GeminiServiceError: LocalizedError, Equatable {
    case missingApiKey
    case invalidURL
    case unreadableImage
    case emptyResponse
    case invalidJSON(String)
    case apiError(code: Int, message: String)
    case httpError(statusCode: Int, rawBody: String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "API key is missing. Please check Settings."
        case .invalidURL:
            return "Failed to construct Gemini API URL."
        case .unreadableImage:
            return "Could not read or compress the receipt image."
        case .emptyResponse:
            return "Gemini returned an empty response (No text generated)."
        case .invalidJSON(let detail):
            return "Failed to parse receipt JSON from AI: \(detail)"
        case .apiError(let code, let message):
            return "Gemini Error \(code): \(message)"
        case .httpError(let statusCode, let rawBody):
            return "Gemini Failed (\(statusCode)): \(rawBody)"
        }
    }

    var isApiKeyIssue: Bool {
        switch self {
        case .missingApiKey:
            return true
        case .apiError(_, let message):
            return message.localizedCaseInsensitiveContains("API key")
        case .httpError(_, let rawBody):
            return rawBody.localizedCaseInsensitiveContains("API key")
        default:
            return false
        }
    }

    var friendlyMessage: String {
        let raw = errorDescription ?? "Unknown error"
        if raw.contains("429") || raw.contains("RESOURCE_EXHAUSTED") {
            return "Quota Exceeded. You are using the Free Tier and have hit the rate limit.\n\nPlease wait a moment or switch to a 'Flash' model (it has higher limits)."
        }
        if raw.contains("503") {
            return "Gemini Service is overloaded. Please try again in a few seconds."
        }
        if case .apiError(_, let message) = self, !message.isEmpty {
            return message
        }
        if let jsonStart = raw.firstIndex(of: "{") {
            let jsonSubstring = String(raw[jsonStart...])
            if let data = jsonSubstring.data(using: .utf8),
               let parsed = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data),
               !parsed.error.message.isEmpty {
                return parsed.error.message
            }
        }
        if raw.count > 200 {
            return String(raw.prefix(200)) + "..."
        }
        return raw
    }
}

final class GeminiService {
    private let settingsStore: SettingsStore
    private let receiptRepository: ReceiptRepositoryProtocol
    private let urlSession: URLSession

    init(
        settingsStore: SettingsStore,
        receiptRepository: ReceiptRepositoryProtocol,
        urlSession: URLSession = .shared
    ) {
        self.settingsStore = settingsStore
        self.receiptRepository = receiptRepository
        self.urlSession = urlSession
    }

    /// Fetches available Gemini models matching Android's exact filter & sort order.
    func fetchAvailableModels(apiKey: String) async -> [String] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return [] }

        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")
        components?.queryItems = [URLQueryItem(name: "key", value: trimmedKey)]
        guard let url = components?.url else { return [] }

        do {
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return []
            }

            let decoded = try JSONDecoder().decode(GeminiModelListResponse.self, from: data)
            let models = decoded.models ?? []

            return models
                .filter { model in
                    let lowerName = model.name.lowercased()
                    let isGenerative = model.supportedGenerationMethods?.contains("generateContent") == true
                    let isGemini = lowerName.contains("gemini")
                    let isEligible = lowerName.contains("flash") || lowerName.contains("pro") || lowerName.contains("hydrogen")
                    return isGenerative && isGemini && isEligible
                }
                .map { model in
                    model.name.hasPrefix("models/") ? String(model.name.dropFirst("models/".count)) : model.name
                }
                .sorted { lhs, rhs in
                    let lhsHydrogen = lhs.contains("hydrogen")
                    let rhsHydrogen = rhs.contains("hydrogen")
                    if lhsHydrogen != rhsHydrogen {
                        return lhsHydrogen && !rhsHydrogen
                    }
                    let lhsFlash = lhs.contains("flash")
                    let rhsFlash = rhs.contains("flash")
                    if lhsFlash != rhsFlash {
                        return lhsFlash && !rhsFlash
                    }
                    return lhs > rhs
                }
        } catch {
            return []
        }
    }

    /// Analyzes a receipt image stored at `imageURL`, matches categories, persists to SwiftData, and returns the receipt ID.
    func analyzeReceipt(imageURL: URL) async throws -> String {
        let (apiKey, modelName, categories) = try await MainActor.run {
            let key = settingsStore.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = settingsStore.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
            let cats = try receiptRepository.fetchAllCategories()
            return (key, model, cats)
        }

        guard !apiKey.isEmpty else {
            throw GeminiServiceError.missingApiKey
        }

        let effectiveModel = modelName.isEmpty ? SettingsStore.Defaults.geminiModel : modelName
        let categoryNames = categories.map(\.name)

        // Encode image as JPEG (quality 0.8) -> base64
        let base64Image: String
        if let uiImage = UIImage(contentsOfFile: imageURL.path),
           let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
            base64Image = jpegData.base64EncodedString()
        } else if let rawData = try? Data(contentsOf: imageURL), !rawData.isEmpty {
            base64Image = rawData.base64EncodedString()
        } else {
            throw GeminiServiceError.unreadableImage
        }

        let prompt = """
        Analyze this receipt. Extract data to match the JSON structure exactly.
        RULES:
        1. Date must be in format "YYYY-MM-DD HH:mm:ss". If time is missing on receipt, use "00:00:00".
        2. Currency must be the 3-letter ISO 4217 code (e.g., EUR, USD, CZK, GBP). Infer from symbol or address.
        3. For 'items', price must be the TOTAL price for that line (qty * unit_price).
        4. Pick the single best category for this receipt from this list: [\(categoryNames.joined(separator: ", "))].
           Return the exact name in the 'categoryName' field.
        """

        let responseSchema = buildResponseSchema(categoryNames: categoryNames)

        let payload = GeminiGenerateRequest(
            contents: [
                GeminiContent(parts: [
                    GeminiPart(text: prompt),
                    GeminiPart(inlineData: GeminiInlineData(mimeType: "image/jpeg", data: base64Image))
                ])
            ],
            generationConfig: GeminiGenerationConfig(
                responseMimeType: "application/json",
                responseSchema: responseSchema
            )
        )

        var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(effectiveModel):generateContent"
        )
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else {
            throw GeminiServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        guard (200...299).contains(statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                throw GeminiServiceError.apiError(
                    code: errorResponse.error.code,
                    message: errorResponse.error.message
                )
            }
            let rawText = String(data: data, encoding: .utf8) ?? "Unknown HTTP error"
            throw GeminiServiceError.httpError(statusCode: statusCode, rawBody: rawText)
        }

        let generateResponse = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        guard let rawJsonText = generateResponse.candidates?.first?.content?.parts.first(where: { $0.text != nil })?.text,
              !rawJsonText.isEmpty else {
            throw GeminiServiceError.emptyResponse
        }

        let cleanedJsonText = stripMarkdownCodeFences(rawJsonText)
        guard let jsonData = cleanedJsonText.data(using: .utf8) else {
            throw GeminiServiceError.invalidJSON("Invalid UTF-8 content")
        }

        let result: ReceiptAnalysisResult
        do {
            result = try JSONDecoder().decode(ReceiptAnalysisResult.self, from: jsonData)
        } catch {
            throw GeminiServiceError.invalidJSON(error.localizedDescription)
        }

        let parsedDate = DateUtils.parseGeminiDate(result.date)
        let matchedCategory = categories.first { category in
            guard let name = result.categoryName else { return false }
            return category.name.caseInsensitiveCompare(name) == .orderedSame
        }

        let receiptId = imageURL.deletingPathExtension().lastPathComponent
        let itemSnapshots = result.items.map { item in
            ReceiptItemSnapshot(
                id: UUID().uuidString,
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
                price: item.price
            )
        }

        let newReceipt = ReceiptSnapshot(
            id: receiptId,
            storeName: result.storeName,
            totalAmount: result.totalAmount,
            dateTimestamp: parsedDate,
            currency: result.currency.uppercased(),
            imageFileName: imageURL.lastPathComponent,
            metadata: ReceiptMetadataSnapshot(
                paymentMethod: result.metadata?.paymentMethod,
                transactionId: result.metadata?.transactionId
            ),
            category: matchedCategory,
            items: itemSnapshots
        )

        try await MainActor.run {
            try receiptRepository.saveReceipt(newReceipt)
        }

        return receiptId
    }

    private func buildResponseSchema(categoryNames: [String]) -> JSONValue {
        var categoryProp: [String: JSONValue] = ["type": .string("STRING")]
        if !categoryNames.isEmpty {
            categoryProp["enum"] = .array(categoryNames.map { .string($0) })
        }

        return .object([
            "type": .string("OBJECT"),
            "properties": .object([
                "storeName": .object(["type": .string("STRING")]),
                "totalAmount": .object(["type": .string("NUMBER")]),
                "currency": .object([
                    "type": .string("STRING"),
                    "description": .string("ISO Code")
                ]),
                "date": .object([
                    "type": .string("STRING"),
                    "description": .string("YYYY-MM-DD HH:mm:ss")
                ]),
                "categoryName": .object(categoryProp),
                "items": .object([
                    "type": .string("ARRAY"),
                    "items": .object([
                        "type": .string("OBJECT"),
                        "properties": .object([
                            "name": .object(["type": .string("STRING")]),
                            "quantity": .object(["type": .string("NUMBER")]),
                            "unit": .object([
                                "type": .string("STRING"),
                                "nullable": .bool(true)
                            ]),
                            "price": .object(["type": .string("NUMBER")])
                        ])
                    ])
                ]),
                "metadata": .object([
                    "type": .string("OBJECT"),
                    "properties": .object([
                        "paymentMethod": .object(["type": .string("STRING")]),
                        "transactionId": .object(["type": .string("STRING")])
                    ])
                ])
            ]),
            "required": .array([
                .string("storeName"),
                .string("totalAmount"),
                .string("date"),
                .string("items")
            ])
        ])
    }

    private func stripMarkdownCodeFences(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            if let firstNewline = trimmed.firstIndex(of: "\n") {
                trimmed = String(trimmed[trimmed.index(after: firstNewline)...])
            }
            if trimmed.hasSuffix("```") {
                trimmed = String(trimmed.dropLast(3))
            }
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
