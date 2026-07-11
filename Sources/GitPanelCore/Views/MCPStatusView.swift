import SwiftUI

public struct MCPStatusView: View {
    @Bindable var monitor = MCPServerMonitor.shared
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
                    if monitor.servers.isEmpty {
                        Text("No MCP servers configured in claude_desktop_config.json")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(monitor.servers, id: \.serverName) { server in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(server.isAlive ? Color.green : Color.red)
                                    .frame(width: 10, height: 10)
                                
                                VStack(alignment: .leading) {
                                    Text(server.serverName)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(server.command)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                
                                Text(server.isAlive ? "Online" : "Offline")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(server.isAlive ? .green : .red)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                        }
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
            
            Image(systemName: "network")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("MCP Servers")
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
        }
        .frame(height: 28)
    }
}
