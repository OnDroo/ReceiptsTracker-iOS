import SwiftData
import SwiftUI

@main
@MainActor
struct ReceiptsTrackerApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppNavigationView()
                .environment(container)
                .modelContainer(container.modelContainer)
        }
    }
}