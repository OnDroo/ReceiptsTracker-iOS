import PhotosUI
import SwiftUI

struct ScanReceiptView: View {
    @Environment(AppContainer.self) private var container

    let onScanFinished: (String) -> Void
    let onOpenSettings: () -> Void
    var onDismiss: (() -> Void)? = nil

    @State private var scanViewModel: ScanReceiptViewModel?
    @State private var settingsViewModel: SettingsViewModel?
    @State private var isShowingCameraScanner: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var scannerErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.groupedBackground
                    .ignoresSafeArea()

                if let scanViewModel, scanViewModel.isAnalyzing {
                    AnalyzingOverlayView(message: "Analyzing Receipt…")
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else {
                    captureOptionsContent
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(onDismiss == nil ? .large : .inline)
            .toolbar {
                if let onDismiss {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: onDismiss) {
                            Label("Close", systemImage: "xmark")
                        }
                        .disabled(scanViewModel?.isAnalyzing == true)
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingCameraScanner) {
                DocumentScannerView(
                    onScanComplete: { image in
                        isShowingCameraScanner = false
                        scanViewModel?.analyzeImage(image)
                    },
                    onCancel: {
                        isShowingCameraScanner = false
                    },
                    onError: { error in
                        isShowingCameraScanner = false
                        scannerErrorMessage = error.localizedDescription
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(
                isPresented: Binding(
                    get: { scanViewModel?.showRetryDialog ?? false },
                    set: { newValue in
                        if !newValue {
                            scanViewModel?.dismissErrorAndDiscard()
                        }
                    }
                )
            ) {
                if let scanViewModel, let settingsViewModel {
                    ErrorRetrySheet(
                        errorMessage: scanViewModel.lastErrorMessage,
                        isApiKeyIssue: scanViewModel.isApiKeyMissingOrWrong,
                        settingsViewModel: settingsViewModel,
                        onDiscard: {
                            scanViewModel.dismissErrorAndDiscard()
                            onDismiss?()
                        },
                        onRetry: {
                            scanViewModel.retryAnalysis()
                        }
                    )
                }
            }
            .alert("Scanner Unavailable", isPresented: Binding(
                get: { scannerErrorMessage != nil },
                set: { if !$0 { scannerErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { scannerErrorMessage = nil }
            } message: {
                Text(scannerErrorMessage ?? "")
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    defer { selectedPhotoItem = nil }
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        scanViewModel?.analyzeImageData(data)
                    }
                }
            }
            .onChange(of: scanViewModel?.analyzedReceiptId) { _, newId in
                if let newId {
                    onScanFinished(newId)
                }
            }
            .task {
                if scanViewModel == nil {
                    scanViewModel = ScanReceiptViewModel(
                        geminiService: container.geminiService,
                        fileStorage: container.fileStorage
                    )
                }
                if settingsViewModel == nil {
                    settingsViewModel = SettingsViewModel(
                        settingsStore: container.settingsStore,
                        geminiService: container.geminiService
                    )
                }
            }
        }
    }

    private var captureOptionsContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.accentColor)
                        .padding(22)
                        .background(Color.accentColor.opacity(0.12), in: Circle())

                    Text("Scan or Import a Receipt")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("Capture a paper receipt with the document scanner or pick an existing photo. Gemini extracts the store, items, totals, and category automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                if container.settingsStore.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gemini API Key Needed")
                                .font(.subheadline.weight(.semibold))
                            Text("Add your free Google AI Studio API key in Settings before scanning.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Open Settings") {
                                onDismiss()
                                onOpenSettings()
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.top, 2)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .nativeCardSurface(cornerRadius: 16)
                }

                AdaptiveGlassContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        Button {
                            if DocumentScannerView.isSupported {
                                isShowingCameraScanner = true
                            } else {
                                scannerErrorMessage = "Document scanning requires a physical camera. Use \"Import from Photos\" on Simulator."
                            }
                        } label: {
                            Label("Scan with Camera", systemImage: "camera.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .adaptiveGlassButtonStyle(prominent: true)
                        .controlSize(.large)

                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            Label("Import from Photos", systemImage: "photo.on.rectangle.angled")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .adaptiveGlassButtonStyle(prominent: false)
                        .controlSize(.large)
                    }
                }
                .frame(maxWidth: 420)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ScanReceiptView(
        onScanFinished: { _ in },
        onOpenSettings: {},
        onDismiss: {}
    )
    .environment(AppContainer.preview)
}
