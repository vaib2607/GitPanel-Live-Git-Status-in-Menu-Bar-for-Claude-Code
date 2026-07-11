import Foundation
import os.log

private let logger = Logger(subsystem: "com.gitpanel", category: "GitHubService")

enum GitHubAuthStatus: Sendable {
    case authenticated(token: String)
    case notAuthenticated
    case binaryNotFound
}

struct GitHubService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API (backward-compatible)

    func isAvailable() async -> Bool {
        if ShellRunner.resolveBinary("gh") != nil { return true }
        if case .authenticated = await checkAuthStatus() { return true }
        return false
    }

    func isAuthenticated() async -> Bool {
        if case .authenticated = await checkAuthStatus() { return true }
        return false
    }

    func prStatus(repo: URL) async throws -> PRStatus {
        let auth = await checkAuthStatus()
        switch auth {
        case .authenticated(let token):
            let owner = try await remoteOwner(repo: repo)
            let name = try await remoteRepoName(repo: repo)
            let branch = try? await currentBranch(repo: repo)
            let prs = try await listPRs(repo: name, owner: owner, branch: branch, token: token)
            return prs.isEmpty ? .noPRs : .pullRequests(prs)
        case .notAuthenticated, .binaryNotFound:
            return try await prStatusViaCLI(repo: repo)
        }
    }

    // MARK: - Native GitHub API

    func listPRs(
        repo: String,
        owner: String,
        branch: String?,
        token: String
    ) async throws -> [PRInfo] {
        var allPRs: [PRInfo] = []
        var urlString = "https://api.github.com/repos/\(owner)/\(repo)/pulls?state=open&per_page=100"

        while !urlString.isEmpty, let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("GitPanel/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            try handleRateLimit(response: response)
            try validateHTTPResponse(response: response)

            guard let decoded = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw GitPanelError.jsonParsingError("Failed to decode pull requests")
            }

            for dict in decoded {
                guard let number = dict["number"] as? Int,
                      let title = dict["title"] as? String,
                      let state = dict["state"] as? String,
                      let headDict = dict["head"] as? [String: Any],
                      let headRef = headDict["ref"] as? String,
                      let userDict = dict["user"] as? [String: Any],
                      let login = userDict["login"] as? String
                else { continue }

                let htmlUrl = dict["html_url"] as? String
                    ?? dict["url"] as? String
                    ?? ""
                let draft = dict["draft"] as? Bool ?? false
                let reviewDecision: String? = draft ? "DRAFT" : nil
                let mergeable = dict["mergeable"] as? Bool

                let pr = PRInfo(
                    number: number,
                    title: title,
                    url: htmlUrl,
                    state: state.uppercased(),
                    author: login,
                    branch: headRef,
                    reviewDecision: reviewDecision,
                    mergeable: mergeable
                )

                if let branch, headRef == branch {
                    allPRs.insert(pr, at: 0)
                } else {
                    allPRs.append(pr)
                }
            }

            urlString = nextPageURL(response: response) ?? ""
        }

        return allPRs
    }

    func getPRStatus(
        repo: String,
        owner: String,
        number: Int,
        token: String
    ) async throws -> PRInfo {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/pulls/\(number)"
        guard let url = URL(string: urlString) else {
            throw GitPanelError.githubAPIError(statusCode: 0, message: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GitPanel/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        try handleRateLimit(response: response)
        try validateHTTPResponse(response: response)

        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let prNumber = dict["number"] as? Int,
              let title = dict["title"] as? String,
              let state = dict["state"] as? String,
              let headDict = dict["head"] as? [String: Any],
              let headRef = headDict["ref"] as? String,
              let userDict = dict["user"] as? [String: Any],
              let login = userDict["login"] as? String
        else {
            throw GitPanelError.jsonParsingError("Failed to decode PR #\(number)")
        }

        let htmlUrl = dict["html_url"] as? String
            ?? dict["url"] as? String
            ?? ""
        let draft = dict["draft"] as? Bool ?? false
        let reviewDecision: String? = draft ? "DRAFT" : nil

        return PRInfo(
            number: prNumber,
            title: title,
            url: htmlUrl,
            state: state.uppercased(),
            author: login,
            branch: headRef,
            reviewDecision: reviewDecision,
            mergeable: dict["mergeable"] as? Bool
        )
    }

    func checkAuthStatus() async -> GitHubAuthStatus {
        if let token = extractTokenFromGH() {
            return .authenticated(token: token)
        }
        if let token = extractTokenFromConfig() {
            return .authenticated(token: token)
        }
        return ShellRunner.resolveBinary("gh") != nil ? .notAuthenticated : .binaryNotFound
    }

    // MARK: - gh CLI Fallback

    private func prStatusViaCLI(repo: URL) async throws -> PRStatus {
        guard let resolvedGh = ShellRunner.resolveBinary("gh") else {
            return .notInstalled
        }

        do {
            let output = try await ShellRunner.run(
                resolvedGh,
                ["pr", "list", "--json", "number,title,url,state,author,headRefName,reviewDecision,isDraft,mergeable"],
                at: repo.path
            )

            guard let data = output.data(using: .utf8),
                  let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { return .noPRs }

            let prs: [PRInfo] = arr.compactMap { dict in
                guard let number = dict["number"] as? Int,
                      let title = dict["title"] as? String,
                      let url = dict["url"] as? String,
                      let state = dict["state"] as? String,
                      let branch = dict["headRefName"] as? String
                else { return nil }

                let authorStr: String
                if let authorDict = dict["author"] as? [String: Any], let login = authorDict["login"] as? String {
                    authorStr = login
                } else if let authorName = dict["author"] as? String {
                    authorStr = authorName
                } else {
                    authorStr = "unknown"
                }

                return PRInfo(
                    number: number,
                    title: title,
                    url: url,
                    state: state,
                    author: authorStr,
                    branch: branch,
                    reviewDecision: dict["reviewDecision"] as? String,
                    mergeable: dict["mergeable"] as? Bool
                )
            }

            return prs.isEmpty ? .noPRs : .pullRequests(prs)
        } catch ShellError.commandFailed(let code, _, _, _, _) where code == 127 {
            return .notInstalled
        }
    }

    // MARK: - Token Extraction

    private func extractTokenFromGH() -> String? {
        guard let ghPath = ShellRunner.resolveBinary("gh") else { return nil }
        let semaphore = DispatchSemaphore(value: 0)
        var token: String?
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["auth", "token"]
        process.environment = ShellRunner.processEnvironment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in
            semaphore.signal()
        }
        do {
            try process.run()
            semaphore.wait()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let output, !output.isEmpty, !output.contains("not logged in") {
                token = output
            }
        } catch {
            return nil
        }
        return token
    }

    private func extractTokenFromConfig() -> String? {
        let homePath: String
        if let override = ShellRunner.homeEnvironmentOverride {
            homePath = override
        } else if let envHome = ProcessInfo.processInfo.environment["HOME"], !envHome.isEmpty {
            homePath = envHome
        } else {
            homePath = NSHomeDirectory()
        }
        let home = URL(fileURLWithPath: homePath)
        let configPaths = [
            home.appendingPathComponent(".config/gh/hosts.yml"),
            home.appendingPathComponent(".config/gh/config.yml"),
        ]

        for configURL in configPaths {
            guard let content = try? String(contentsOf: configURL, encoding: .utf8) else { continue }
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("oauth_token:") || trimmed.hasPrefix("token:") {
                    let value = trimmed
                        .replacingOccurrences(of: "oauth_token:", with: "")
                        .replacingOccurrences(of: "token:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty { return value }
                }
            }
        }
        return nil
    }

    // MARK: - Git Helpers

    private func remoteOwner(repo: URL) async throws -> String {
        let output = try await ShellRunner.run(
            ShellRunner.resolveBinary("git") ?? "/usr/bin/git",
            ["remote", "get-url", "origin"],
            at: repo.path
        )
        return try parseGitHubOwner(from: output)
    }

    private func remoteRepoName(repo: URL) async throws -> String {
        let output = try await ShellRunner.run(
            ShellRunner.resolveBinary("git") ?? "/usr/bin/git",
            ["remote", "get-url", "origin"],
            at: repo.path
        )
        return try parseGitHubRepoName(from: output)
    }

    private func currentBranch(repo: URL) async throws -> String {
        try await ShellRunner.run(
            ShellRunner.resolveBinary("git") ?? "/usr/bin/git",
            ["branch", "--show-current"],
            at: repo.path
        )
    }

    private func parseGitHubOwner(from remoteURL: String) throws -> String {
        let url = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.contains("github.com") {
            let parts = url
                .replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: "https://github.com/", with: "")
                .replacingOccurrences(of: "github.com/", with: "")
                .components(separatedBy: "/")
            if parts.count >= 1 { return parts[0] }
        }
        throw GitPanelError.githubAPIError(statusCode: 0, message: "Cannot parse GitHub owner from: \(url)")
    }

    private func parseGitHubRepoName(from remoteURL: String) throws -> String {
        let url = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.contains("github.com") {
            let parts = url
                .replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: "https://github.com/", with: "")
                .replacingOccurrences(of: "github.com/", with: "")
                .components(separatedBy: "/")
            if parts.count >= 2 {
                return parts[1].replacingOccurrences(of: ".git", with: "")
            }
        }
        throw GitPanelError.githubAPIError(statusCode: 0, message: "Cannot parse GitHub repo from: \(url)")
    }

    // MARK: - HTTP Helpers

    private func handleRateLimit(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        if let remainingStr = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           let remaining = Int(remainingStr), remaining == 0 {
            var retryAfter: Date?
            if let resetStr = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
               let resetTimestamp = TimeInterval(resetStr) {
                retryAfter = Date(timeIntervalSince1970: resetTimestamp)
            }
            throw GitPanelError.rateLimited(retryAfter: retryAfter)
        }
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
            var retryAfter: Date?
            if let retryStr = httpResponse.value(forHTTPHeaderField: "Retry-After"),
               let seconds = TimeInterval(retryStr) {
                retryAfter = Date().addingTimeInterval(seconds)
            }
            throw GitPanelError.rateLimited(retryAfter: retryAfter)
        }
    }

    private func validateHTTPResponse(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitPanelError.networkUnavailable
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw GitPanelError.authenticationRequired
        case 403:
            throw GitPanelError.authenticationRequired
        case 404:
            throw GitPanelError.githubAPIError(statusCode: 404, message: "Resource not found")
        case 500...599:
            throw GitPanelError.githubAPIError(statusCode: httpResponse.statusCode, message: "Server error")
        default:
            throw GitPanelError.githubAPIError(statusCode: httpResponse.statusCode, message: "Unexpected status code")
        }
    }

    private func nextPageURL(response: URLResponse) -> String? {
        guard let httpResponse = response as? HTTPURLResponse,
              let linkHeader = httpResponse.value(forHTTPHeaderField: "Link")
        else { return nil }

        let parts = linkHeader.components(separatedBy: ",")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("rel=\"next\"") {
                if let startRange = trimmed.range(of: "<"),
                   let endRange = trimmed.range(of: ">") {
                    return String(trimmed[startRange.upperBound..<endRange.lowerBound])
                }
            }
        }
        return nil
    }
}
