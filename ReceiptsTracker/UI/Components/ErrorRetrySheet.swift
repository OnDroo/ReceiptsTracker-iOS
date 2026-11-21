import SwiftUI

struct ErrorRetrySheet: View {
    let errorMessage: String
    let isApiKeyIssue: Bool
    @Bindable var settingsViewModel: SettingsViewModel
    let onDiscard: () -> Void
    let onRetry: () -> Void

    @State private var isApiKeyVisible: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Analysis Failed")
                }

                if isApiKeyIssue {
                    Section {
                        HStack(spacing: 8) {
                            if isApiKeyVisible {
                                TextField("Paste API Key here", text: apiKeyBinding)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("Paste API Key here", text: apiKeyBinding)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }

                            Button(isApiKeyVisible ? "Hide" : "Show") {
                                isApiKeyVisible.toggle()
                            }
                            .font(.subheadline)
                        }
                    } header: {
                        Text("Gemini API Key")
                    } footer: {
                        Text("Required for receipt analysis. Get a free key at Google AI Studio.")
                    }
                } else {
                    Section {
                        if settingsViewModel.isFetchingModels {
                            HStack {
                                ProgressView()
                                Text("Fetching models…")
                                    .foregroundStyle(.secondary)
                            }
                        } else if settingsViewModel.availableModels.isEmpty {
                            Text("No models found. Check your API key in Settings.")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("AI Model", selection: $settingsViewModel.selectedModel) {
                                ForEach(settingsViewModel.availableModels, id: \.self) { model in
                                    VStack(alignment: .leading) {
                                        Text(model)
                                        if let subtitle = modelSubtitle(for: model) {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .tag(model)
                                }
                            }
                            .pickerStyle(.navigationLink)
                        }
                    } header: {
                        Text("Try a Different Model")
                    } footer: {
                        Text("Flash models are faster with higher free-tier limits. Pro models excel on complex receipts.")
                    }
                }

                Section {
                    Button {
                        settingsViewModel.commitApiKey(settingsViewModel.localApiKey)
                        onRetry()
                    } label: {
                        Label("Retry Analysis", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .adaptiveGlassButtonStyle(prominent: true)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    Button(role: .destructive, action: onDiscard) {
                        Label("Discard Receipt", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Could Not Analyze")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .destructive, action: onDiscard) {
                        Label("Discard", systemImage: "xmark")
                    }
                }
            }
            .task {
                if !settingsViewModel.savedApiKey.isEmpty {
                    await settingsViewModel.fetchModels()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { settingsViewModel.localApiKey },
            set: { settingsViewModel.onApiKeyEdited($0) }
        )
    }

    private func modelSubtitle(for model: String) -> String? {
        if model.localizedCaseInsensitiveContains("flash") {
            return "Fastest • Free Tier Available"
        } else if model.localizedCaseInsensitiveContains("pro") {
            return "Best Quality • Free Tier Available"
        }
        return nil
    }
}
