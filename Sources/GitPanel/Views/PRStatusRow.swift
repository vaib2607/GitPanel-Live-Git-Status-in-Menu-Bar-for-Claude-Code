import SwiftUI

struct PRStatusRow: View {
    let prStatus: PRStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.pull")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            if prStatus.exists, let title = prStatus.title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, design: .monospaced))
                        .lineLimit(1)
                    if let num = prStatus.number {
                        Text("#\(num) · \(prStatus.state ?? "")")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let url = prStatus.url, let u = URL(string: url) {
                    Link(destination: u) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 13, design: .monospaced))
                    }
                    .buttonStyle(.plain)
                }
            } else if prStatus.available {
                Text("No open pull request")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Text("gh not installed")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .frame(minHeight: 32)
    }
}
