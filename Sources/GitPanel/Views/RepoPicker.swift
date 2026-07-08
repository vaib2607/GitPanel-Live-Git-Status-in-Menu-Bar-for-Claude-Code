import SwiftUI

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
                if panel.runModal() == .OK, let url = panel.url {
                    onPicked(url)
                    dismiss()
                }
            }
            .padding()
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        }
        .padding()
        .frame(width: 260, height: 120)
    }
}
