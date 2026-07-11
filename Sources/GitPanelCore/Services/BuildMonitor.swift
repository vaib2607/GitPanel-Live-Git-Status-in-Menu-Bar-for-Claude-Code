import Foundation

public struct BuildStatus: Equatable {
    public var isBuilding: Bool
    public var toolName: String
    public var startTime: Date?
}

@MainActor
@Observable public final class BuildMonitor {
    public static let shared = BuildMonitor()
    
    public var currentBuild: BuildStatus? = nil
    
    private var checkTask: Task<Void, Never>?
    private let toolsToMonitor = ["xcodebuild", "swift build", "npm run", "cargo build", "make"]
    
    private init() {}
    
    public func start() {
        guard checkTask == nil else { return }
        checkTask = Task {
            while !Task.isCancelled {
                await checkProcesses()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    public func stop() {
        checkTask?.cancel()
        checkTask = nil
        currentBuild = nil
    }
    
    private func checkProcesses() async {
        guard let pgrep = ShellRunner.resolveBinary("pgrep") else { return }
        
        for tool in toolsToMonitor {
            let toolBase = tool.components(separatedBy: " ").first ?? tool
            do {
                let output = try await ShellRunner.run(pgrep, ["-l", toolBase])
                if !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if currentBuild?.toolName != tool {
                        currentBuild = BuildStatus(isBuilding: true, toolName: tool, startTime: Date())
                    }
                    return // Found an active build
                }
            } catch {
                // pgrep returns error if not found, ignore
            }
        }
        
        if currentBuild != nil {
            currentBuild = nil
        }
    }
}
