import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    var onDismiss: (() -> Void)? = nil

    @State private var viewModel: SettingsViewModel?
    @State private var isApiKeyVisible: Bool = false

    var body: some View {
        Group {
            if let viewModel {
                settingsForm(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.groupedBackground)
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            if let onDismiss {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = SettingsViewModel(
                    settingsStore: container.settingsStore,
                    geminiService: container.geminiService
                )
                viewModel = vm
                if !vm.savedApiKey.isEmpty {
                    await vm.fetchModels()
                }
            }
        }
    }

    @ViewBuilder
    private func settingsForm(viewModel: SettingsViewModel) -> some View {
        @Bindable var bindableVM = viewModel

        Form {
            Section {
                Picker(selection: $bindableVM.currency) {
                    ForEach(CurrencyUtils.supportedCurrencies, id: \.self) { code in
                        Text("\(code) (\(CurrencyUtils.symbol(for: code)))")
                            .tag(code)
                    }
                } label: {
                    Label("Currency", systemImage: "banknote")
                }
            } header: {
                Text("Preferences")
            } footer: {
                Text("Dashboard totals and charts are converted into your preferred currency.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(Color.accentColor)

                        Text("Gemini API Key")
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        if !viewModel.savedApiKey.isEmpty {
                            Text("Saved")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.14), in: Capsule())
                        }

                        Button(isApiKeyVisible ? "Hide" : "Show") {
                            isApiKeyVisible.toggle()
                        }
                        .font(.subheadline)
                        .buttonStyle(.borderless)
                    }

                    if isApiKeyVisible {
                        TextField("Paste Gemini API Key", text: apiKeyBinding(for: viewModel))
                            .font(.subheadline.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Paste Gemini API Key", text: apiKeyBinding(for: viewModel))
                            .font(.subheadline.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .padding(.vertical, 2)

                if viewModel.isFetchingModels {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Fetching available models…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    NavigationLink {
                        ModelPickerListView(
                            availableModels: viewModel.availableModels,
                            selectedModel: $bindableVM.selectedModel,
                            isFetching: viewModel.isFetchingModels,
                            onRefresh: {
                                Task { await viewModel.fetchModels() }
                            }
                        )
                    } label: {
                        HStack {
                            Label("AI Model", systemImage: "sparkles")
                            Spacer()
                            Text(viewModel.selectedModel)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                if !viewModel.savedApiKey.isEmpty {
                    Button {
                        Task { await viewModel.fetchModels() }
                    } label: {
                        Label("Refresh Available Models", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isFetchingModels)
                }
            } header: {
                Text("AI Configuration")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your API key is stored securely in the iOS Keychain. Flash is fastest for quick receipts; Pro handles complex line items best.")
                    if let url = URL(string: "https://aistudio.google.com/") {
                        Link("Get a free API key at Google AI Studio", destination: url)
                            .font(.footnote)
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Storage", value: "SwiftData & Keychain")
            }
        }
        .onDisappear {
            viewModel.commitApiKey(viewModel.localApiKey)
        }
    }

    private func apiKeyBinding(for viewModel: SettingsViewModel) -> Binding<String> {
        Binding(
            get: { viewModel.localApiKey },
            set: { viewModel.onApiKeyEdited($0) }
        )
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

private struct ModelPickerListView: View {
    let availableModels: [String]
    @Binding var selectedModel: String
    let isFetching: Bool
    let onRefresh: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var displayedModels: [String] {
        if availableModels.isEmpty {
            return [selectedModel]
        }
        if availableModels.contains(selectedModel) {
            return availableModels
        }
        return [selectedModel] + availableModels
    }

    var body: some View {
        List {
            if availableModels.isEmpty && !isFetching {
                Section {
                    Text("No models loaded yet. Enter a valid Gemini API key and tap Refresh.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Gemini Models") {
                ForEach(displayedModels, id: \.self) { model in
                    Button {
                        selectedModel = model
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model)
                                    .foregroundStyle(.primary)

                                if model.localizedCaseInsensitiveContains("flash") {
                                    Text("Fastest • Free Tier Available")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
                                } else if model.localizedCaseInsensitiveContains("pro") {
                                    Text("Best Quality • Free Tier Available")
                                        .font(.caption)
                                        .foregroundStyle(.indigo)
                                }
                            }

                            Spacer()

                            if model == selectedModel {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("AI Model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isFetching)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppContainer.preview)
}
