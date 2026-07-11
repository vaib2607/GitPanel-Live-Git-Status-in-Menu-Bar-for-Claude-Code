import SwiftUI

public struct TimelineView: View {
    @Bindable var engine = TimelineEngine.shared
    var onBack: () -> Void
    
    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            PanelDivider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if engine.events.isEmpty {
                        Text("No deep work timeline events yet.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(engine.events) { event in
                            HStack(alignment: .top, spacing: 12) {
                                VStack {
                                    Circle()
                                        .fill(color(for: event.type))
                                        .frame(width: 12, height: 12)
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 2)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.type.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(color(for: event.type))
                                    Text(event.message)
                                        .font(.system(size: 13))
                                    Text("\(event.timestamp, style: .time) - \(event.timestamp, style: .date)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.bottom, 12)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }
    
    private func color(for type: String) -> Color {
        switch type {
        case "commit": return .green
        case "build": return .blue
        case "mcp_start": return .orange
        default: return .secondary
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
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("Deep Work Timeline")
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
        }
        .frame(height: 28)
    }
}
