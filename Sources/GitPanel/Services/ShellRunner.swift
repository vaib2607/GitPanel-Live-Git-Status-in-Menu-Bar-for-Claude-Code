import Foundation

struct ShellResult {
    let output: String
    let exitCode: Int
    var success: Bool { exitCode == 0 }
}

struct ShellRunner {
    static func run(executable: String, arguments: [String], workingDirectory: URL? = nil) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let wd = workingDirectory {
            process.currentDirectoryURL = wd
        }
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return ShellResult(output: "Failed to launch: \(error)", exitCode: -1)
        }
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        let combined = out.isEmpty ? err : out
        return ShellResult(output: combined.trimmingCharacters(in: .whitespacesAndNewlines), exitCode: Int(process.terminationStatus))
    }
}
