import SwiftUI

enum AppTab: Hashable {
    case dashboard
    case receipts
    case scan
}

struct AppNavigationView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab: AppTab = .dashboard
    @State private var dashboardPath: [String] = []
    @State private var receiptsPath: [String] = []
    @State private var selectedReceiptId: String?
    @State private var isPresentingSettings: Bool = false

    var body: some View {
        tabContent
            .sheet(isPresented: $isPresentingSettings) {
                NavigationStack {
                    SettingsView {
                        isPresentingSettings = false
                    }
                }
            }
            .onChange(of: horizontalSizeClass) { _, newSizeClass in
                // Preserve open receipt seamlessly when folding/unfolding iPhone Duo
                if newSizeClass == .regular {
                    if let currentPushed = receiptsPath.last {
                        selectedReceiptId = currentPushed
                        receiptsPath.removeAll()
                    }
                } else {
                    if let currentSelected = selectedReceiptId, receiptsPath.isEmpty {
                        receiptsPath = [currentSelected]
                    }
                }
            }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }
                .tag(AppTab.dashboard)

            receiptsTab
                .tabItem {
                    Label("Receipts", systemImage: "doc.text.magnifyingglass")
                }
                .tag(AppTab.receipts)

            scanTab
                .tabItem {
                    Label("Scan", systemImage: "doc.viewfinder")
                }
                .tag(AppTab.scan)
        }
    }

    private var dashboardTab: some View {
        NavigationStack(path: $dashboardPath) {
            DashboardView(
                onOpenReceipts: {
                    selectedTab = .receipts
                },
                onSelectReceipt: { receiptId in
                    dashboardPath.append(receiptId)
                },
                onOpenSettings: {
                    isPresentingSettings = true
                }
            )
            .navigationDestination(for: String.self) { receiptId in
                ReceiptDetailView(receiptId: receiptId) {
                    if !dashboardPath.isEmpty {
                        dashboardPath.removeLast()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var receiptsTab: some View {
        if horizontalSizeClass == .regular {
            // Unfolded iPhone Duo (7.6" inner display) & iPad: side-by-side split view
            NavigationSplitView {
                ReceiptListView(
                    selectedReceiptId: $selectedReceiptId,
                    usesSplitSelection: true,
                    onSelectReceipt: { receiptId in
                        selectedReceiptId = receiptId
                    },
                    onScanTap: {
                        selectedTab = .scan
                    }
                )
            } detail: {
                if let selectedReceiptId {
                    ReceiptDetailView(receiptId: selectedReceiptId) {
                        self.selectedReceiptId = nil
                    }
                } else {
                    ContentUnavailableView(
                        "Select a Receipt",
                        systemImage: "doc.text",
                        description: Text("Choose a receipt from the list to view items and the original scan.")
                    )
                }
            }
        } else {
            NavigationStack(path: $receiptsPath) {
                ReceiptListView(
                    selectedReceiptId: $selectedReceiptId,
                    usesSplitSelection: false,
                    onSelectReceipt: { receiptId in
                        selectedReceiptId = receiptId
                        receiptsPath.append(receiptId)
                    },
                    onScanTap: {
                        selectedTab = .scan
                    }
                )
                .navigationDestination(for: String.self) { receiptId in
                    ReceiptDetailView(receiptId: receiptId) {
                        selectedReceiptId = nil
                        if !receiptsPath.isEmpty {
                            receiptsPath.removeLast()
                        }
                    }
                }
            }
        }
    }

    private var scanTab: some View {
        ScanReceiptView(
            onScanFinished: { newReceiptId in
                openReceipt(id: newReceiptId)
            },
            onOpenSettings: {
                isPresentingSettings = true
            }
        )
    }

    private func openReceipt(id: String) {
        selectedReceiptId = id
        selectedTab = .receipts
        if horizontalSizeClass != .regular {
            receiptsPath = [id]
        }
    }
}

#Preview {
    AppNavigationView()
        .environment(AppContainer.preview)
}
