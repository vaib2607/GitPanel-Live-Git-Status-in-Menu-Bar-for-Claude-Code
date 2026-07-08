import SwiftUI

struct ChangesRow: View {
    let status: GitStatus

    var body: some View {
        InfoRow(
            icon: "doc.plaintext",
            title: "Changes",
            value: status.hasChanges ? "\(status.total)" : "No changes",
            valueColor: status.hasChanges ? .primary : .secondary
        )
    }
}
