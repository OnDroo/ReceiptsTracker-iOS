import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    enum Keys {
        static let apiKey = "api_key"
        static let currency = "currency"
        static let geminiModel = "gemini_model"
    }

    enum Defaults {
        static let currency = "EUR"
        static let geminiModel = "gemini-4-hydrogen"
    }

    private let secretStorage: SecretStorageProtocol
    private let userDefaults: UserDefaults

    var apiKey: String {
        didSet {
            secretStorage.save(apiKey, forKey: Keys.apiKey)
        }
    }

    var currency: String {
        didSet {
            userDefaults.set(currency, forKey: Keys.currency)
        }
    }

    var selectedModel: String {
        didSet {
            userDefaults.set(selectedModel, forKey: Keys.geminiModel)
        }
    }

    init(
        secretStorage: SecretStorageProtocol = KeychainHelper.shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.secretStorage = secretStorage
        self.userDefaults = userDefaults
        self.apiKey = secretStorage.load(forKey: Keys.apiKey) ?? ""
        self.currency = userDefaults.string(forKey: Keys.currency) ?? Defaults.currency
        self.selectedModel = userDefaults.string(forKey: Keys.geminiModel) ?? Defaults.geminiModel
    }
}
