import SwiftUI

@main
struct ReceiptsTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

private struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("Receipts")
                    .font(.title.bold())
                Text("iOS SwiftUI port scaffold ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Receipts")
        }
    }
}

#Preview {
    ContentView()
}