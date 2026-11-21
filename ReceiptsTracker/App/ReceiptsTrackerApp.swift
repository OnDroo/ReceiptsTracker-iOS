import SwiftData
import SwiftUI

@main
@MainActor
struct ReceiptsTrackerApp: App {
    @State private var container: AppContainer

    init() {
        let isDemoMode = ProcessInfo.processInfo.arguments.contains("--demo-data")
        _container = State(initialValue: isDemoMode ? AppContainer.makeDemo() : AppContainer())
    }

    var body: some Scene {
        WindowGroup {
            AppNavigationView()
                .environment(container)
                .modelContainer(container.modelContainer)
        }
    }
}