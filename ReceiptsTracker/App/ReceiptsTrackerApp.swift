import SwiftData
import SwiftUI

@main
@MainActor
struct ReceiptsTrackerApp: App {
    @State private var container: AppContainer

    init() {
        let isDemoMode = ProcessInfo.processInfo.arguments.contains("--demo-data")
        let initialContainer = isDemoMode ? AppContainer.makeDemo() : AppContainer()
        AppContainer.active = initialContainer
        _container = State(initialValue: initialContainer)
    }

    var body: some Scene {
        WindowGroup {
            AppNavigationView()
                .environment(container)
                .modelContainer(container.modelContainer)
        }
    }
}