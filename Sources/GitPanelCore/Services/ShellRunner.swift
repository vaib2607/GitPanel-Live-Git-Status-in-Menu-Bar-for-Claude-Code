import Foundation
import os.log

private let logger = Logger(subsystem: "com.gitpanel", category: "ShellRunner")

public enum ShellError: Error, LocalizedError, CustomStringConvertible {
    case commandFailed(Int32, command: String, workingDirectory: String?, stdout: String, stderr: String)
    case binaryNotFound(String)
    case encodingError(Error)
    case timeout(command: String, workingDirectory: String?, duration: TimeInterval)
    case processGroupKillFailed(pid: Int32, command: String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let code, let command, let workDir, let stdout, let stderr):
            var desc = "Command failed with exit code \(code): \(command)"
            if let workDir { desc += " (in \(workDir))" }
            if !stderr.isEmpty { desc += "\nstderr: \(stderr)" }
            if !stdout.isEmpty { desc += "\nstdout: \(stdout)" }
            return desc
        case .binaryNotFound(let name):
            return "Binary not found: \(name)"
        case .encodingError(let error):
            return "String encoding error: \(error.localizedDescription)"
        case .timeout(let command, let workDir, let duration):
            var desc = "Command timed out after \(duration)s: \(command)"
            if let workDir { desc += " (in \(workDir))" }
            return desc
        case .processGroupKillFailed(let pid, let command):
            return "Failed to kill process group \(pid) for command: \(command)"
        }
    }

    public var description: String {
        errorDescription ?? "Unknown shell error"
    }
}

private final class DataBox: @unchecked Sendable {
    var data = Data()
}

struct ShellRunner {
    private static let lock = NSLock()
    private static var _pathEnvironmentOverride: String?
    private static var _homeEnvironmentOverride: String?

    static var pathEnvironmentOverride: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _pathEnvironmentOverride
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _pathEnvironmentOverride = newValue
        }
    }

    static var homeEnvironmentOverride: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _homeEnvironmentOverride
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _homeEnvironmentOverride = newValue
        }
    }

    private static let resolvedPath: String = {
        let homebrewPath = "/opt/homebrew/bin"
        let localBinPath = "/usr/local/bin"
        let systemPath = "/usr/bin:/bin:/usr/sbin:/sbin"
        return "\(homebrewPath):\(localBinPath):\(systemPath)"
    }()

    static var processEnvironment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        if let pathOverride = pathEnvironmentOverride {
            env["PATH"] = pathOverride
        } else if let pathVal = ProcessInfo.processInfo.environment["PATH"] {
            env["PATH"] = pathVal
        }
        if let homeOverride = homeEnvironmentOverride {
            env["HOME"] = homeOverride
        } else if let homeVal = ProcessInfo.processInfo.environment["HOME"] {
            env["HOME"] = homeVal
        }
        let existing = env["PATH"] ?? ""
        if existing.isEmpty {
            env["PATH"] = resolvedPath
        } else {
            env["PATH"] = "\(existing):\(resolvedPath)"
        }
        return env
    }

    static func resolveBinary(_ name: String) -> String? {
        guard !name.isEmpty else { return nil }
        if name.hasPrefix("/") {
            return FileManager.default.fileExists(atPath: name) ? name : nil
        }
        let paths = processEnvironment["PATH"]?.split(separator: ":").map(String.init) ?? []
        for path in paths {
            let fullPath = (path as NSString).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    private static func killProcessGroup(pid: Int32, command: String) {
        let pgid = getpgid(pid)
        if pgid > 0 {
            logger.warning("Killing process group \(pgid) for command: \(command)")
            killpg(pgid, SIGKILL)
        } else {
            logger.warning("Falling back to killing process \(pid) directly for command: \(command)")
            kill(pid, SIGKILL)
        }
    }

    @discardableResult
    static func run(_ executable: String, _ arguments: [String], at path: String? = nil, timeout: TimeInterval = 30) async throws -> String {
        guard let resolvedExecutable = resolveBinary(executable) else {
            throw ShellError.binaryNotFound(executable)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedExecutable)
        process.arguments = arguments
        process.environment = processEnvironment

        if let path = path {
            process.currentDirectoryURL = URL(fileURLWithPath: path)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutBox = DataBox()
        let stderrBox = DataBox()

        let commandString = "\(executable) \(arguments.joined(separator: " "))"

        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "com.gitpanel.shellrunner.pipes")

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                } else {
                    queue.async { stdoutBox.data.append(data) }
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                } else {
                    queue.async { stderrBox.data.append(data) }
                }
            }

            let startTime = Date()

            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(timeout))
                guard !Task.isCancelled, process.isRunning else { return }

                let elapsed = Date().timeIntervalSince(startTime)
                logger.warning("Timeout reached (\(elapsed)s). Terminating process group for: \(commandString)")

                process.terminate()

                try? await Task.sleep(for: .seconds(1))
                if process.isRunning {
                    logger.error("Process still alive after graceful termination. Force killing process group for: \(commandString)")
                    Self.killProcessGroup(pid: process.processIdentifier, command: commandString)
                }
            }

            process.terminationHandler = { proc in
                timeoutTask.cancel()

                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let elapsed = Date().timeIntervalSince(startTime)

                queue.async {
                    let status = proc.terminationStatus
                    let stdoutString = String(data: stdoutBox.data, encoding: .utf8) ?? ""
                    let stderrString = String(data: stderrBox.data, encoding: .utf8) ?? ""

                    if status == 0 {
                        logger.debug("Command completed in \(elapsed)s: \(commandString)")
                        continuation.resume(returning: stdoutString.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else if proc.terminationReason == .uncaughtSignal && proc.terminationStatus == SIGTERM {
                        continuation.resume(throwing: ShellError.timeout(command: commandString, workingDirectory: path, duration: elapsed))
                    } else {
                        continuation.resume(throwing: ShellError.commandFailed(status, command: commandString, workingDirectory: path, stdout: stdoutString, stderr: stderrString))
                    }
                }
            }

            do {
                try process.run()
                logger.debug("Launched process \(process.processIdentifier) for: \(commandString)")
            } catch {
                timeoutTask.cancel()
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: ShellError.encodingError(error))
            }
        }
    }

    @discardableResult
    static func runSync(_ executable: String, _ arguments: [String], at path: String? = nil, timeout: TimeInterval = 30) throws -> String {
        guard let resolvedExecutable = resolveBinary(executable) else {
            throw ShellError.binaryNotFound(executable)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedExecutable)
        process.arguments = arguments
        process.environment = processEnvironment

        if let path = path {
            process.currentDirectoryURL = URL(fileURLWithPath: path)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutBox = DataBox()
        let stderrBox = DataBox()
        let queue = DispatchQueue(label: "com.gitpanel.shellrunner.syncpipes")

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
            } else {
                queue.async {
                    stdoutBox.data.append(data)
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                stderrPipe.fileHandleForReading.readabilityHandler = nil
            } else {
                queue.async {
                    stderrBox.data.append(data)
                }
            }
        }

        let deadline = Date().addingTimeInterval(timeout)
        let startTime = Date()

        do {
            try process.run()
            logger.debug("Launched sync process \(process.processIdentifier) for: \(executable) \(arguments.joined(separator: " "))")
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw ShellError.encodingError(error)
        }

        process.waitUntilExit()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        queue.sync {}

        let remainingOut = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let remainingErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let finalOutData = queue.sync { stdoutBox.data + remainingOut }
        let finalErrData = queue.sync { stderrBox.data + remainingErr }

        let stdoutString = String(data: finalOutData, encoding: .utf8) ?? ""
        let stderrString = String(data: finalErrData, encoding: .utf8) ?? ""

        let commandString = "\(executable) \(arguments.joined(separator: " "))"
        let elapsed = Date().timeIntervalSince(startTime)

        if Date() >= deadline && process.isRunning {
            logger.warning("Sync timeout reached (\(elapsed)s). Killing process group for: \(commandString)")
            process.terminate()
            try? Thread.sleep(forTimeInterval: 1)
            if process.isRunning {
                Self.killProcessGroup(pid: process.processIdentifier, command: commandString)
            }
            throw ShellError.timeout(command: commandString, workingDirectory: path, duration: elapsed)
        }

        let status = process.terminationStatus
        guard status == 0 else {
            if process.terminationReason == .uncaughtSignal && status == SIGTERM {
                throw ShellError.timeout(command: commandString, workingDirectory: path, duration: elapsed)
            }
            throw ShellError.commandFailed(status, command: commandString, workingDirectory: path, stdout: stdoutString, stderr: stderrString)
        }

        logger.debug("Sync command completed in \(elapsed)s: \(commandString)")
        return stdoutString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
