import SwiftUI

public struct MultiAgentDashboardView: View {
    @Bindable var engine = AIEngine.shared
    var onBack: () -> Void
    
    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            PanelDivider()
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(engine.providers.indices, id: \.self) { index in
                        let provider = engine.providers[index]
                        agentCard(for: provider)
                    }
                }
                .padding(12)
            }
        }
    }
    
    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .hoverable(radius: 6)
            }
            .buttonStyle(.plain)
            
            Image(systemName: "cpu")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("AI Providers")
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
        }
        .frame(height: 28)
    }
    
    private func agentCard(for provider: any AIProviderProtocol) -> some View {
        HStack(spacing: 12) {
            // Icon
            Text(provider.icon)
                .font(.system(size: 20))
                .frame(width: 32, height: 32)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(provider.name)
                        .font(.system(size: 13, weight: .semibold))
                    
                    Circle()
                        .fill(provider.isRunning ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }
                
                if provider.isRunning {
                    HStack(spacing: 8) {
                        if let duration = provider.sessionDuration {
                            Text("Running • \(formatDuration(duration))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Running")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        if let tokens = provider.tokenUsage?.total, tokens > 0 {
                            Text("• \(tokens) tokens")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Idle")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}
