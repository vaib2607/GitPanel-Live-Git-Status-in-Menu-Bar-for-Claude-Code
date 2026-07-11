import Foundation

struct GitService {
    static let gitPath: String = {
        if let path = ShellRunner.resolveBinary("git") {
            return path
        }
        return "/usr/bin/git"
    }()

    static let ghPath: String = {
        if let path = ShellRunner.resolveBinary("gh") {
            return path
        }
        return "/usr/local/bin/gh"
    }()

    private static func git(_ args: [String], repo: URL) async throws -> String {
        try await ShellRunner.run(gitPath, args, at: repo.path)
    }

    // MARK: - Core Queries

    func isGitRepo(repo: URL) async throws -> Bool {
        do {
            let output = try await Self.git(["rev-parse", "--is-inside-work-tree"], repo: repo)
            return output == "true"
        } catch {
            return false
        }
    }

    func currentBranch(repo: URL) async throws -> String {
        let output = try await Self.git(["branch", "--show-current"], repo: repo)
        return output.isEmpty ? "(detached HEAD)" : output
    }

    func branches(repo: URL) async throws -> [GitBranch] {
        let format = "%(refname:short)|%(refname:strip=2)|%(upstream:short)|%(upstream:ahead-count)|%(upstream:behind-count)|%(HEAD)"
        let output = try await Self.git(["for-each-ref", "--format=\(format)", "refs/heads/", "refs/remotes/"], repo: repo)

        return output.components(separatedBy: "\n").compactMap { line in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 6 else { return nil }
            let name = parts[0]
            let isCurrent = parts[5] == "true"
            let upstream = parts[2]
            let ahead = Int(parts[3]) ?? 0
            let behind = Int(parts[4]) ?? 0
            let isRemote = name.contains("/")

            return GitBranch(
                name: name,
                isCurrent: isCurrent,
                isRemote: isRemote,
                remoteName: nil,
                upstreamName: upstream.isEmpty ? nil : upstream,
                ahead: ahead,
                behind: behind
            )
        }
    }

    func checkout(repo: URL, branch: String) async throws {
        try await Self.git(["checkout", branch], repo: repo)
    }

    func createBranch(repo: URL, name: String) async throws {
        try await Self.git(["checkout", "-b", name], repo: repo)
    }

    func deleteBranch(repo: URL, name: String) async throws {
        try await Self.git(["branch", "-d", name], repo: repo)
    }

    func commit(repo: URL, message: String, autoStage: Bool = true) async throws {
        if autoStage {
            try await Self.git(["add", "-A"], repo: repo)
        }
        try await Self.git(["commit", "-m", message], repo: repo)
    }

    func aheadBehind(repo: URL) async throws -> (ahead: Int, behind: Int) {
        do {
            let output = try await Self.git(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], repo: repo)
            let parts = output.split(separator: "\t").map { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
            if parts.count == 2 { return (ahead: parts[1], behind: parts[0]) }
            return (0, 0)
        } catch {
            return (0, 0)
        }
    }

    func push(repo: URL, setUpsream: Bool = true) async throws {
        if setUpsream {
            try await Self.git(["push", "--set-upstream", "origin", "HEAD"], repo: repo)
        } else {
            try await Self.git(["push"], repo: repo)
        }
    }

    func pull(repo: URL) async throws {
        try await Self.git(["pull"], repo: repo)
    }

    func worktrees(repo: URL) async throws -> [GitWorktree] {
        let output = try await Self.git(["worktree", "list", "--porcelain"], repo: repo)
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
        let output = try await Self.git(["submodule", "status"], repo: repo)
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
        let output = try await Self.git(["remote", "-v"], repo: repo)
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
        let output = try await Self.git(["status", "--porcelain=v2", "--branch"], repo: repo)
        return Self.parsePorcelainV2(output)
    }

    static func parsePorcelainV2(_ output: String) -> PorcelainV2Result {
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

        branch = (head.isEmpty || head.contains("detached")) ? "(detached HEAD)" : head

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
        let output = try await Self.git(["diff", "--numstat"], repo: repo)
        return Self.parseNumstat(output)
    }

    func diffCachedNumstat(repo: URL) async throws -> NumstatResult {
        let output = try await Self.git(["diff", "--cached", "--numstat"], repo: repo)
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
        var gitDir = repo.appendingPathComponent(".git")
        let fm = FileManager.default

        var isDir: ObjCBool = false
        if fm.fileExists(atPath: gitDir.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                if let content = try? String(contentsOf: gitDir, encoding: .utf8),
                   content.hasPrefix("gitdir:") {
                    let path = content.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                    let resolvedURL: URL
                    if path.hasPrefix("/") {
                        resolvedURL = URL(fileURLWithPath: path)
                    } else {
                        resolvedURL = repo.appendingPathComponent(path)
                    }
                    gitDir = resolvedURL
                }
            }
        }

        if fm.fileExists(atPath: gitDir.appendingPathComponent("MERGE_HEAD").path) {
            return .merging
        }
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

    func updateState(repo: URL) async throws -> GitStateSnapshot {
        let isRepo = (try? await isGitRepo(repo: repo)) ?? false
        guard isRepo else {
            return GitStateSnapshot(
                isGitRepo: false,
                repoName: repo.lastPathComponent,
                branchName: "",
                isAheadOfRemote: false,
                isBehindRemote: false,
                hasChanges: false,
                stagedCount: 0,
                unstagedCount: 0,
                untrackedCount: 0,
                conflictCount: 0,
                linesAdded: 0,
                linesDeleted: 0,
                lastCommitHash: "",
                lastCommitMessage: "",
                lastCommitDate: .distantPast,
                remotes: [],
                remoteName: "",
                submodules: [],
                branches: [],
                repoState: .clean
            )
        }

        let porcelain = try await porcelainV2(repo: repo)

        let branchName = porcelain.branch
        let isAheadOfRemote = porcelain.ahead > 0
        let isBehindRemote = porcelain.behind > 0
        let hasChanges = porcelain.staged > 0 || porcelain.unstaged > 0 || porcelain.untracked > 0

        let stagedCount = porcelain.staged
        let unstagedCount = porcelain.unstaged
        let untrackedCount = porcelain.untracked
        let conflictCount = porcelain.conflicts

        let repoName = repo.lastPathComponent

        let numstat = try await diffNumstat(repo: repo)
        let cachedNumstat = try await diffCachedNumstat(repo: repo)
        let linesAdded = numstat.added + cachedNumstat.added
        let linesDeleted = numstat.deleted + cachedNumstat.deleted

        var lastCommitHash = ""
        var lastCommitMessage = ""
        var lastCommitDate = Date.distantPast

        if let output = try? await Self.git(["log", "-1", "--format=%H%n%s%n%ai"], repo: repo) {
            let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
            lastCommitHash = lines.count > 0 ? String(lines[0]) : ""
            lastCommitMessage = lines.count > 1 ? String(lines[1]) : ""
            if lines.count > 2, let date = Self.parseGitDate(String(lines[2])) {
                lastCommitDate = date
            }
        }

        let remotesList = (try? await remotes(repo: repo)) ?? []
        let remoteName = remotesList.first?.name ?? ""

        let submodulesList = (try? await submodules(repo: repo)) ?? []

        let branchesList = (try? await branches(repo: repo)) ?? []

        let repoState = (try? await detectRepoState(repo: repo)) ?? .clean

        return GitStateSnapshot(
            isGitRepo: isRepo,
            repoName: repoName,
            branchName: branchName,
            isAheadOfRemote: isAheadOfRemote,
            isBehindRemote: isBehindRemote,
            hasChanges: hasChanges,
            stagedCount: stagedCount,
            unstagedCount: unstagedCount,
            untrackedCount: untrackedCount,
            conflictCount: conflictCount,
            linesAdded: linesAdded,
            linesDeleted: linesDeleted,
            lastCommitHash: lastCommitHash,
            lastCommitMessage: lastCommitMessage,
            lastCommitDate: lastCommitDate,
            remotes: remotesList,
            remoteName: remoteName,
            submodules: submodulesList,
            branches: branchesList,
            repoState: repoState
        )
    }

    // MARK: - Stash Operations

    func stash(repo: URL, message: String? = nil) async throws {
        if let message = message {
            try await Self.git(["stash", "push", "-m", message], repo: repo)
        } else {
            try await Self.git(["stash", "push"], repo: repo)
        }
    }

    func stashPop(repo: URL) async throws {
        try await Self.git(["stash", "pop"], repo: repo)
    }

    func stashDrop(repo: URL, index: Int = 0) async throws {
        try await Self.git(["stash", "drop", "stash@{\(index)}"], repo: repo)
    }

    func stashList(repo: URL) async throws -> [StashEntry] {
        let output = try await Self.git(["stash", "list"], repo: repo)
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        return output.components(separatedBy: "\n").compactMap { line in
            let parts = line.components(separatedBy: ": ")
            guard parts.count >= 2 else { return nil }
            let ref = parts[0].trimmingCharacters(in: .whitespaces)
            let message = parts.dropFirst().joined(separator: ": ").trimmingCharacters(in: .whitespaces)
            return StashEntry(ref: ref, message: message)
        }
    }

    func stashShow(repo: URL, index: Int = 0) async throws -> String {
        return try await Self.git(["stash", "show", "-p", "stash@{\(index)}"], repo: repo)
    }

    // MARK: - Diff Operations

    func diff(repo: URL, path: String? = nil) async throws -> String {
        if let path = path {
            return try await Self.git(["diff", "HEAD", "--", path], repo: repo)
        }
        return try await Self.git(["diff", "HEAD"], repo: repo)
    }

    func diffCached(repo: URL, path: String? = nil) async throws -> String {
        if let path = path {
            return try await Self.git(["diff", "--cached", "--", path], repo: repo)
        }
        return try await Self.git(["diff", "--cached"], repo: repo)
    }

    func diffStat(repo: URL, path: String? = nil) async throws -> String {
        if let path = path {
            return try await Self.git(["diff", "HEAD", "--stat", "--", path], repo: repo)
        }
        return try await Self.git(["diff", "HEAD", "--stat"], repo: repo)
    }

    func diffNumstat(repo: URL, path: String? = nil) async throws -> [(path: String, added: Int, deleted: Int)] {
        let output: String
        if let path = path {
            output = try await Self.git(["diff", "HEAD", "--numstat", "--", path], repo: repo)
        } else {
            output = try await Self.git(["diff", "HEAD", "--numstat"], repo: repo)
        }
        return Self.parseNumstatDetail(output)
    }

    func listConflicts(repo: URL) async throws -> [ConflictedFile] {
        let output = try await Self.git(["diff", "--name-only", "--diff-filter=U"], repo: repo)
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }.map { ConflictedFile(path: $0) }
    }

    func resolveConflict(repo: URL, path: String, strategy: ConflictStrategy) async throws {
        switch strategy {
        case .ours:
            try await Self.git(["checkout", "--ours", path], repo: repo)
        case .theirs:
            try await Self.git(["checkout", "--theirs", path], repo: repo)
        case .mark:
            try await Self.git(["add", path], repo: repo)
        }
    }

    // MARK: - Helpers

    private static func parseGitDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }

    private static func parseNumstatDetail(_ output: String) -> [(path: String, added: Int, deleted: Int)] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t")
            guard parts.count >= 3 else { return nil }
            return (path: String(parts[2]), added: Int(parts[0]) ?? 0, deleted: Int(parts[1]) ?? 0)
        }
    }
}

struct ConflictedFile: Identifiable, Hashable {
    let path: String
    var id: String { path }
}

enum ConflictStrategy: String, CaseIterable {
    case ours
    case theirs
    case mark
}

struct StashEntry: Identifiable, Hashable {
    let ref: String
    let message: String
    var id: String { ref }
}
