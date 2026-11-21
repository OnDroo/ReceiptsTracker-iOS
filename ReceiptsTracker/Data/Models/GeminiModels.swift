import Foundation

// MARK: - Model Listing

struct GeminiModelListResponse: Codable, Sendable {
    let models: [GeminiModelInfo]?
}

struct GeminiModelInfo: Codable, Sendable {
    let name: String
    let displayName: String?
    let supportedGenerationMethods: [String]?
}

// MARK: - Error Response

struct GeminiErrorResponse: Codable, Sendable {
    let error: GeminiErrorContent
}

struct GeminiErrorContent: Codable, Sendable {
    let code: Int
    let message: String
    let status: String?
}

// MARK: - Generate Content Request

struct GeminiGenerateRequest: Encodable, Sendable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

struct GeminiContent: Codable, Sendable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable, Sendable {
    let text: String?
    let inlineData: GeminiInlineData?

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }

    init(inlineData: GeminiInlineData) {
        self.text = nil
        self.inlineData = inlineData
    }
}

struct GeminiInlineData: Codable, Sendable {
    let mimeType: String
    let data: String
}

struct GeminiGenerationConfig: Encodable, Sendable {
    let responseMimeType: String
    let responseSchema: JSONValue
}

// MARK: - Generate Content Response

struct GeminiGenerateResponse: Decodable, Sendable {
    let candidates: [GeminiCandidate]?
}

struct GeminiCandidate: Decodable, Sendable {
    let content: GeminiContent?
}

// MARK: - Parsed Receipt Result

struct ReceiptAnalysisResult: Decodable, Sendable {
    let storeName: String
    let totalAmount: Double
    let currency: String
    let date: String
    let categoryName: String?
    let items: [AnalysisItem]
    let metadata: AnalysisMetadata?

    private enum CodingKeys: String, CodingKey {
        case storeName, totalAmount, currency, date, categoryName, items, metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.storeName = try container.decode(String.self, forKey: .storeName)
        self.totalAmount = try container.decode(Double.self, forKey: .totalAmount)
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "EUR"
        self.date = try container.decode(String.self, forKey: .date)
        self.categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        self.items = try container.decodeIfPresent([AnalysisItem].self, forKey: .items) ?? []
        self.metadata = try container.decodeIfPresent(AnalysisMetadata.self, forKey: .metadata)
    }
}

struct AnalysisItem: Decodable, Sendable {
    let name: String
    let quantity: Double
    let unit: String?
    let price: Double

    private enum CodingKeys: String, CodingKey {
        case name, quantity, unit, price
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.quantity = try container.decodeIfPresent(Double.self, forKey: .quantity) ?? 1.0
        self.unit = try container.decodeIfPresent(String.self, forKey: .unit)
        self.price = try container.decode(Double.self, forKey: .price)
    }
}

struct AnalysisMetadata: Decodable, Sendable {
    let paymentMethod: String?
    let transactionId: String?
}

// MARK: - Recursive JSON Value for Gemini responseSchema

enum JSONValue: Encodable, Sendable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case array([JSONValue])
    case object([String: JSONValue])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .array(let array):
            try container.encode(array)
        case .object(let dict):
            try container.encode(dict)
        }
    }
}
