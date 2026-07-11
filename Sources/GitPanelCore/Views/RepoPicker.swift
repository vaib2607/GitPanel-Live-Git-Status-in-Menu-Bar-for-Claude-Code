import SwiftUI
import AppKit

struct RepoPicker: View {
    let onPicked: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Select a repository")
                .font(.headline)
            Button("Choose Folder...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        onPicked(url)
                    }
                    dismiss()
                }
            }
            .padding()
            .accessibilityLabel("Choose repository folder")
            .accessibilityHint("Opens a file dialog to select a local git repository folder")
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .accessibilityLabel("Cancel")
            .accessibilityHint("Closes the repository picker without selecting a repository")
        }
        .padding()
        .frame(width: 260, height: 120)
    }
}
