import SwiftUI

struct AnalyzingOverlayView: View {
    var message: String = "Analyzing Receipt…"

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(.accentColor)

            VStack(spacing: 6) {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Extracting store, line items, and category with Gemini")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(maxWidth: 320)
        .adaptiveGlassRect(cornerRadius: 26, interactive: false)
        .padding(24)
    }
}
