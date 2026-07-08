import SwiftUI

struct UsageView: View {
    @ObservedObject var settings: AppSettings
    let usage: UsageData
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch usage.source {
            case .claude:
                claudeBlock
            case .cursor:
                cursorBlock
            case .manual:
                manualBlock
            case .none:
                emptyBlock
            }

            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Manual override")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                TextField("e.g. 80%  ·  120 credits", text: $settings.usageRemaining)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }
        }
    }

    private var claudeBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Claude Code")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                if let plan = usage.cursorPlan {
                    Text(plan)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.quaternary))
                }
            }

            HStack(spacing: 16) {
                statBlock("In", value: formatTokens(usage.inputTokens))
                statBlock("Out", value: formatTokens(usage.outputTokens))
                statBlock("Cache", value: formatTokens(usage.cacheReadTokens))
            }

            Divider()

            HStack {
                Text("Estimated cost")
                    .font(.system(size: 13, design: .monospaced))
                Spacer()
                Text(String(format: "$%.2f", usage.estimatedCost))
                    .font(.system(size: 24, weight: .light, design: .monospaced))
            }

            Text("Offline estimate from ~/.claude transcripts.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cursorBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Cursor")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                if let plan = usage.cursorPlan {
                    Text(plan)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.quaternary))
                }
            }
            Text("Detailed credit data isn't available locally. Set a manual value below.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var manualBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(settings.usageRemaining.isEmpty ? "No usage value set." : settings.usageRemaining)
                .font(.system(size: 13, design: .monospaced))
            Text("Manual entry from Settings.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private var emptyBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No usage data found.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("Claude Code usage is read from ~/.claude. Cursor plan is detected locally; live credits require manual entry.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statBlock(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
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
