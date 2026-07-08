import Foundation

struct GitService {
    static let gitPath: String = {
        if let path = try? ShellRunner.runSync("/usr/bin/env which git") {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "/usr/bin/git" : trimmed
        }
        return "/usr/bin/git"
    }()

    static let ghPath: String = {
        if let path = try? ShellRunner.runSync("/usr/bin/env which gh") {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "/usr/local/bin/gh" : trimmed
        }
        return "/usr/local/bin/gh"
    }()

    private static func git(_ args: String, repo: URL) async throws -> String {
        try await ShellRunner.run("\(gitPath) \(args)", at: repo.path)
    }

    // MARK: - Core Queries

    func isGitRepo(repo: URL) async throws -> Bool {
        do {
            let output = try await Self.git("rev-parse --is-inside-work-tree", repo: repo)
            return output == "true"
        } catch {
            return false
        }
    }

    func currentBranch(repo: URL) async throws -> String {
        let output = try await Self.git("branch --show-current", repo: repo)
        return output.isEmpty ? "(detached HEAD)" : output
    }

    func branches(repo: URL) async throws -> [GitBranch] {
        let output = try await Self.git("branch --list --sort=-committerdate", repo: repo)
        return output.split(separator: "\n").compactMap { line in
            var s = String(line).trimmingCharacters(in: .whitespaces)
            let isCurrent = s.hasPrefix("*")
            s = s.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty else { return nil }
            return GitBranch(name: s, isCurrent: isCurrent)
        }
    }

    func checkout(repo: URL, branch: String) async throws {
        let escaped = shellEscape(branch)
        try await Self.git("checkout \(escaped)", repo: repo)
    }

    func createBranch(repo: URL, name: String) async throws {
        let escaped = shellEscape(name)
        try await Self.git("checkout -b \(escaped)", repo: repo)
    }

    func deleteBranch(repo: URL, name: String) async throws {
        try await Self.git("branch -d \(shellEscape(name))", repo: repo)
    }

    func commit(repo: URL, message: String) async throws {
        let escaped = shellEscape(message)
        try await Self.git("commit -m \(escaped)", repo: repo)
    }

    func aheadBehind(repo: URL) async throws -> (ahead: Int, behind: Int) {
        do {
            let output = try await Self.git("rev-list --left-right --count @{upstream}...HEAD", repo: repo)
            let parts = output.split(separator: "\t").map { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
            if parts.count == 2 { return (ahead: parts[1], behind: parts[0]) }
            return (0, 0)
        } catch {
            return (0, 0)
        }
    }

    func push(repo: URL) async throws {
        try await Self.git("push", repo: repo)
    }

    func pull(repo: URL) async throws {
        try await Self.git("pull", repo: repo)
    }

    func worktrees(repo: URL) async throws -> [GitWorktree] {
        let output = try await Self.git("worktree list --porcelain", repo: repo)
        var result: [GitWorktree] = []
        var currentPath: String?
        var currentBranch: String?
        var isCurrent = false
        func flush() {
            if let p = currentPath {
                result.append(GitWorktree(path: p, branch: currentBranch ?? "", isCurrent: isCurrent))
            }
            currentPath = nil; currentBranch = nil; isCurrent = false
        }
        for line in output.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("worktree ") {
                flush()
                currentPath = String(s.dropFirst("worktree ".count))
            } else if s.hasPrefix("branch ") {
                currentBranch = String(s.dropFirst("branch ".count))
            } else if s == "HEAD" {
                isCurrent = true
            }
        }
        flush()
        return result
    }

    func submodules(repo: URL) async throws -> [Submodule] {
        let output = try await Self.git("submodule status", repo: repo)
        return output.split(separator: "\n").compactMap { line in
            var s = String(line).trimmingCharacters(in: .whitespaces)
            s = s.replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: " ", with: "")
            let parts = s.components(separatedBy: " ")
            guard parts.count >= 2 else { return nil }
            let path = parts[1]
            let url = parts.count >= 3 ? parts[2].trimmingCharacters(in: CharacterSet(charactersIn: "()")) : ""
            return Submodule(name: (path as NSString).lastPathComponent, path: path, url: url)
        }
    }

    func remotes(repo: URL) async throws -> [Remote] {
        let output = try await Self.git("remote -v", repo: repo)
        var seen = Set<String>()
        var result: [Remote] = []
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let name = String(parts[0])
            let url = String(parts[1])
                .replacingOccurrences(of: " (fetch)", with: "")
                .replacingOccurrences(of: " (push)", with: "")
            if seen.contains(name) { continue }
            seen.insert(name)
            result.append(Remote(name: name, url: url))
        }
        return result
    }

    func dependencies(repo: URL) -> [String] {
        let fm = FileManager.default
        let candidates = [
            "package.json", "Podfile", "Package.swift", "Gemfile",
            "requirements.txt", "Cargo.toml", "pubspec.yaml",
            "go.mod", "build.gradle", "pom.xml"
        ]
        return candidates.filter { fm.fileExists(atPath: repo.appendingPathComponent($0).path) }
    }

    // MARK: - Porcelain V2

    struct PorcelainV2Result {
        let branch: String
        let head: String
        let upstream: String?
        let ahead: Int
        let behind: Int
        let staged: Int
        let unstaged: Int
        let untracked: Int
        let conflicts: Int
    }

    func porcelainV2(repo: URL) async throws -> PorcelainV2Result {
        let output = try await Self.git("status --porcelain=v2 --branch", repo: repo)
        return Self.parsePorcelainV2(output)
    }

    private static func parsePorcelainV2(_ output: String) -> PorcelainV2Result {
        var branch = ""
        var head = ""
        var upstream: String?
        var ahead = 0, behind = 0
        var staged = 0, unstaged = 0, untracked = 0, conflicts = 0

        for line in output.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("# branch.head ") {
                head = String(s.dropFirst("# branch.head ".count))
            } else if s.hasPrefix("# branch.upstream ") {
                upstream = String(s.dropFirst("# branch.upstream ".count))
            } else if s.hasPrefix("# branch.ab ") {
                let parts = s.components(separatedBy: " ")
                for part in parts {
                    if part.hasPrefix("+"), let v = Int(part.dropFirst()) { ahead = v }
                    if part.hasPrefix("-"), let v = Int(part.dropFirst()) { behind = v }
                }
            } else if s.hasPrefix("?") {
                untracked += 1
            } else if s.hasPrefix("u") {
                conflicts += 1
            } else if s.first == "1" || s.first == "2" {
                let cols = s.split(separator: " ")
                if cols.count >= 2 {
                    let xy = String(cols[1])
                    let x = xy.first!
                    let y = xy.last!
                    if x != "." && x != "?" { staged += 1 }
                    if y != "." && y != "?" { unstaged += 1 }
                }
            }
        }

        branch = head.isEmpty ? "(detached HEAD)" : head

        return PorcelainV2Result(
            branch: branch,
            head: head,
            upstream: upstream,
            ahead: ahead,
            behind: behind,
            staged: staged,
            unstaged: unstaged,
            untracked: untracked,
            conflicts: conflicts
        )
    }

    // MARK: - Numstat

    struct NumstatResult {
        let added: Int
        let deleted: Int
    }

    func diffNumstat(repo: URL) async throws -> NumstatResult {
        let output = try await Self.git("diff --numstat", repo: repo)
        return Self.parseNumstat(output)
    }

    func diffCachedNumstat(repo: URL) async throws -> NumstatResult {
        let output = try await Self.git("diff --cached --numstat", repo: repo)
        return Self.parseNumstat(output)
    }

    private static func parseNumstat(_ output: String) -> NumstatResult {
        var added = 0, deleted = 0
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            added += Int(parts[0]) ?? 0
            deleted += Int(parts[1]) ?? 0
        }
        return NumstatResult(added: added, deleted: deleted)
    }

    // MARK: - Repo State Detection

    func detectRepoState(repo: URL) async throws -> RepoState {
        let gitDir = repo.appendingPathComponent(".git")
        let fm = FileManager.default

        if fm.fileExists(atPath: gitDir.appendingPathComponent("rebase-merge").path) ||
            fm.fileExists(atPath: gitDir.appendingPathComponent("rebase-apply").path) {
            return .rebasing
        }
        if fm.fileExists(atPath: gitDir.appendingPathComponent("CHERRY_PICK_HEAD").path) {
            return .cherryPicking
        }
        if fm.fileExists(atPath: gitDir.appendingPathComponent("REVERT_HEAD").path) {
            return .reverting
        }
        if fm.fileExists(atPath: gitDir.appendingPathComponent("BISECT_LOG").path) {
            return .bisecting
        }

        let headPath = gitDir.appendingPathComponent("HEAD")
        if let head = try? String(contentsOf: headPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !head.hasPrefix("ref: ") {
            return .detachedHEAD
        }

        let porcelain = try await porcelainV2(repo: repo)
        if porcelain.conflicts > 0 { return .mergeConflict }

        let numstat = try await diffNumstat(repo: repo)
        let cached = try await diffCachedNumstat(repo: repo)
        if numstat.added + numstat.deleted + cached.added + cached.deleted > 0 { return .dirty }

        return .clean
    }

    // MARK: - Full State Update

    func updateState(_ state: GitState, repo: URL) async throws {
        let isRepo = (try? await isGitRepo(repo: repo)) ?? false
        state.isGitRepo = isRepo
        guard isRepo else { return }

        let porcelain = try await porcelainV2(repo: repo)

        state.branchName = porcelain.branch
        state.isAheadOfRemote = porcelain.ahead > 0
        state.isBehindRemote = porcelain.behind > 0
        state.hasChanges = porcelain.staged > 0 || porcelain.unstaged > 0 || porcelain.untracked > 0

        state.repoName = repo.lastPathComponent

        let numstat = try await diffNumstat(repo: repo)
        let cachedNumstat = try await diffCachedNumstat(repo: repo)
        state.linesAdded = numstat.added + cachedNumstat.added
        state.linesDeleted = numstat.deleted + cachedNumstat.deleted

        if let output = try? await Self.git("log -1 --format=%H%n%s%n%ai", repo: repo) {
            let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
            state.lastCommitHash = lines.count > 0 ? String(lines[0]) : ""
            state.lastCommitMessage = lines.count > 1 ? String(lines[1]) : ""
            if lines.count > 2, let date = Self.parseGitDate(String(lines[2])) {
                state.lastCommitDate = date
            }
        }

        state.remotes = (try? await remotes(repo: repo)) ?? []
        state.remoteName = state.remotes.first?.name ?? ""

        state.submodules = (try? await submodules(repo: repo)) ?? []

        state.branches = (try? await branches(repo: repo)) ?? []

        state.repoState = (try? await detectRepoState(repo: repo)) ?? .clean

        state.lastUpdated = Date()
    }

    // MARK: - Helpers

    private static func parseGitDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }

    private func shellEscape(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
