import Foundation

enum ShellError: Error, LocalizedError, CustomStringConvertible {
    case commandFailed(Int32, stdout: String, stderr: String)
    case binaryNotFound(String)
    case encodingError(Error)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let code, let stdout, let stderr):
            var desc = "Command failed with exit code \(code)"
            if !stderr.isEmpty { desc += "\nstderr: \(stderr)" }
            if !stdout.isEmpty { desc += "\nstdout: \(stdout)" }
            return desc
        case .binaryNotFound(let name):
            return "Binary not found: \(name)"
        case .encodingError(let error):
            return "String encoding error: \(error.localizedDescription)"
        }
    }

    var description: String {
        errorDescription ?? "Unknown shell error"
    }
}

struct ShellRunner {
    private static let resolvedPath: String = {
        let homebrewPath = "/opt/homebrew/bin"
        let localBinPath = "/usr/local/bin"
        let systemPath = "/usr/bin:/bin:/usr/sbin:/sbin"
        return "\(homebrewPath):\(localBinPath):\(systemPath)"
    }()

    private static var processEnvironment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        let existing = env["PATH"] ?? ""
        env["PATH"] = "\(resolvedPath):\(existing)"
        return env
    }

    @discardableResult
    static func run(_ command: String, at path: String? = nil) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-cl", command]
        process.environment = processEnvironment

        if let path {
            process.currentDirectoryURL = URL(fileURLWithPath: path)
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            throw ShellError.binaryNotFound("/bin/zsh")
        } catch {
            throw ShellError.encodingError(error)
        }

        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        let stdoutString: String
        let stderrString: String
        do {
            stdoutString = try String(data: outData, encoding: .utf8)
                .flatMap { $0.isEmpty ? nil : $0 } ?? ""
            stderrString = try String(data: errData, encoding: .utf8)
                .flatMap { $0.isEmpty ? nil : $0 } ?? ""
        } catch {
            throw ShellError.encodingError(error)
        }

        let status = process.terminationStatus
        guard status == 0 else {
            throw ShellError.commandFailed(status, stdout: stdoutString, stderr: stderrString)
        }

        return stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    static func runSync(_ command: String, at path: String? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-cl", command]
        process.environment = processEnvironment

        if let path {
            process.currentDirectoryURL = URL(fileURLWithPath: path)
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            throw ShellError.binaryNotFound("/bin/zsh")
        } catch {
            throw ShellError.encodingError(error)
        }

        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        let stdoutString: String
        let stderrString: String
        do {
            stdoutString = try String(data: outData, encoding: .utf8)
                .flatMap { $0.isEmpty ? nil : $0 } ?? ""
            stderrString = try String(data: errData, encoding: .utf8)
                .flatMap { $0.isEmpty ? nil : $0 } ?? ""
        } catch {
            throw ShellError.encodingError(error)
        }

        let status = process.terminationStatus
        guard status == 0 else {
            throw ShellError.commandFailed(status, stdout: stdoutString, stderr: stderrString)
        }

        return stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
