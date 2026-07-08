import SwiftUI

struct ChangesRow: View {
    let state: GitState

    var body: some View {
        InfoRow(
            icon: "doc.plaintext",
            title: "Changes",
            value: state.hasChanges ? "\(state.linesAdded + state.linesDeleted) lines" : "No changes",
            valueColor: state.hasChanges ? .primary : .secondary
        )
    }
}
