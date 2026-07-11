import Foundation

public struct MCPStatus: Equatable {
    public var serverName: String
    public var isAlive: Bool
    public var command: String
}

@MainActor
@Observable public final class MCPServerMonitor {
    public static let shared = MCPServerMonitor()
    
    public var servers: [MCPStatus] = []
    
    private var checkTask: Task<Void, Never>?
    
    private init() {}
    
    public func start() {
        guard checkTask == nil else { return }
        checkTask = Task {
            while !Task.isCancelled {
                await checkConfig()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
    
    public func stop() {
        checkTask?.cancel()
        checkTask = nil
    }
    
    private func checkConfig() async {
        let claudeConfigURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
        
        guard let data = try? Data(contentsOf: claudeConfigURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mcpServers = json["mcpServers"] as? [String: [String: Any]] else {
            servers = []
            return
        }
        
        var newServers: [MCPStatus] = []
        for (name, config) in mcpServers {
            let command = config["command"] as? String ?? "unknown"
            // Stub check for process matching command
            let isAlive = await checkProcess(command)
            newServers.append(MCPStatus(serverName: name, isAlive: isAlive, command: command))
        }
        
        self.servers = newServers.sorted(by: { $0.serverName < $1.serverName })
    }
    
    private func checkProcess(_ command: String) async -> Bool {
        guard let pgrep = ShellRunner.resolveBinary("pgrep") else { return false }
        do {
            let output = try await ShellRunner.run(pgrep, ["-f", command])
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }
}
