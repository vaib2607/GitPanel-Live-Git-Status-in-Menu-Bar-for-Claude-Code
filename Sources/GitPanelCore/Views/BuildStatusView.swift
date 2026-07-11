import SwiftUI

public struct BuildStatusView: View {
    @Bindable var monitor = BuildMonitor.shared
    var onBack: () -> Void
    
    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            PanelDivider()
            
            ScrollView {
                VStack(spacing: 12) {
                    if let build = monitor.currentBuild {
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                            VStack(alignment: .leading) {
                                Text("Building: \(build.toolName)")
                                    .font(.system(size: 13, weight: .semibold))
                                if let start = build.startTime {
                                    Text("Started \(start, style: .relative) ago")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.blue.opacity(0.1))
                        )
                    } else {
                        Text("No active builds detected.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
                .padding(16)
            }
        }
        .onAppear { monitor.start() }
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
            
            Image(systemName: "hammer.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("Build Monitor")
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
        }
        .frame(height: 28)
    }
}
