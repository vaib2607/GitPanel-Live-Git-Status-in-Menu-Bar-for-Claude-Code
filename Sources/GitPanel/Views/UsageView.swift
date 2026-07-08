import SwiftUI

struct UsageView: View {
    @Bindable var viewModel: GitPanelViewModel

    var body: some View {
        let usage = viewModel.usage
        let settings = viewModel.settings

        VStack(alignment: .leading, spacing: 8) {
            if usage.tokens > 0 || usage.cost > 0 {
                HStack(spacing: 8) {
                    Text(usage.model.isEmpty ? "Usage" : usage.model)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))

                    if usage.isUsingPlan, !usage.plan.isEmpty {
                        Text(usage.plan)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.quaternary))
                    }
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tokens")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(formatTokens(usage.tokens))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cost")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(String(format: "$%.2f", usage.cost))
                            .font(.system(size: 24, weight: .light, design: .monospaced))
                            .monospacedDigit()
                    }

                    Spacer()
                }

                Text("Offline estimate from local transcripts.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No usage data found.")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Usage is read from local transcripts.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Manual override")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !settings.usageEnabled {
                        Text("Manual")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.orange.opacity(0.2)))
                            .foregroundStyle(.orange)
                    }
                }
                TextField("e.g. 80%  ·  120 credits", text: Binding(
                    get: { viewModel.settings.usageRemaining },
                    set: { viewModel.settings.usageRemaining = $0 }
                ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .contentShape(Rectangle())
            }
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
