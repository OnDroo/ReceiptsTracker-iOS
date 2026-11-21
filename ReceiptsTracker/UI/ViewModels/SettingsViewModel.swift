import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let settingsStore: SettingsStore
    private let geminiService: GeminiService

    var localApiKey: String
    private(set) var availableModels: [String] = []
    private(set) var isFetchingModels: Bool = false

    private var debounceTask: Task<Void, Never>?

    var currency: String {
        get { settingsStore.currency }
        set { settingsStore.currency = newValue }
    }

    var selectedModel: String {
        get { settingsStore.selectedModel }
        set { settingsStore.selectedModel = newValue }
    }

    var savedApiKey: String {
        settingsStore.apiKey
    }

    init(settingsStore: SettingsStore, geminiService: GeminiService) {
        self.settingsStore = settingsStore
        self.geminiService = geminiService
        self.localApiKey = settingsStore.apiKey
    }

    func onApiKeyEdited(_ newValue: String) {
        localApiKey = newValue
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            commitApiKey(newValue)
        }
    }

    func commitApiKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != settingsStore.apiKey else { return }
        settingsStore.apiKey = trimmed
        if !trimmed.isEmpty {
            Task { await fetchModels() }
        } else {
            availableModels = []
        }
    }

    func fetchModels() async {
        let key = settingsStore.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            availableModels = []
            return
        }

        isFetchingModels = true
        defer { isFetchingModels = false }

        let models = await geminiService.fetchAvailableModels(apiKey: key)
        if !models.isEmpty {
            availableModels = models
        }
    }
}
