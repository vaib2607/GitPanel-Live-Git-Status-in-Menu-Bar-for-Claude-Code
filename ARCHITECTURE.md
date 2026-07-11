# GitPanel Architecture

> macOS menu bar app for real-time git repository monitoring and GitHub integration  
> Target: macOS 14+ (Sonoma) | Swift 5.9+ | SwiftUI

---

## 1. Overview

GitPanel is a lightweight, persistent menu bar application that provides real-time git repository status, GitHub PR insights, and Claude Code usage tracking from the macOS menu bar.

**Core value proposition**: Eliminate context switching by surfacing repository state directly in the menu bar — branch status, uncommitted changes, PR CI status, and AI coding tool usage — without requiring a full IDE or terminal.

**Design principles**:
- Zero-config for common git workflows
- Minimal CPU/memory footprint (sub-5MB idle)
- Native macOS feel (menu bar, not dock)
- Secure by default (sandboxed, minimal entitlements)

---

## 2. Module Structure

```
GitPanel/
├── GitPanelCore/          # Shared library (reusable, testable)
│   ├── Services/          # Git, GitHub, Usage, FileWatcher
│   ├── ViewModels/        # @Observable state management
│   ├── Models/            # Data types and enums
│   └── Utilities/         # ShellRunner, helpers
│
└── GitPanel/              # macOS app target
    ├── App/               # MenuBarExtra entry point
    ├── Views/             # SwiftUI views
    ├── Resources/         # Assets, Info.plist
    └── Helpers/           # AppDelegate, UserDefaults
```

### Module Dependencies

```
┌─────────────────────────────────────────┐
│           GitPanel (App)                │
│  ┌─────────────────────────────────┐    │
│  │  Views (SwiftUI)                │    │
│  │  - MenuBarView                  │    │
│  │  - RepoDashboardView           │    │
│  │  - PRStatusView                 │    │
│  │  - UsageInsightsView            │    │
│  └──────────────┬──────────────────┘    │
│                 │                       │
│  ┌──────────────▼──────────────────┐    │
│  │  GitPanelViewModel              │    │
│  │  (central orchestrator)         │    │
│  └──────────────┬──────────────────┘    │
└─────────────────┼───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         GitPanelCore (Library)          │
│  ┌─────────┬──────────┬─────────────┐   │
│  │GitService│GitHubSvc│UsageService │   │
│  └────┬─────┴────┬────┴──────┬──────┘   │
│       │          │           │          │
│  ┌────▼──────────▼───────────▼──────┐   │
│  │  ShellRunner (async process)     │   │
│  └──────────────────────────────────┘   │
│  ┌──────────────────────────────────┐   │
│  │  FileWatcher (FSEventStream)     │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**Why two modules?**
- `GitPanelCore` can be imported by tests, CLI tools, or other apps
- Clear separation of business logic (Core) from UI (App)
- Enables unit testing without launching the full app

---

## 3. Data Flow

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  FSEvents    │───▶│  FileWatcher  │───▶│  GitService  │
│  (OS kernel) │    │  (callback)   │    │  (parse)     │
└──────────────┘    └──────────────┘    └──────┬───────┘
                                               │
                                               ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  GitHub API  │───▶│  GitHubSvc   │───▶│ GitPanel     │
│  (REST/QL)   │    │  (fetch)     │    │ ViewModel    │
└──────────────┘    └──────────────┘    └──────┬───────┘
                                               │
                                               ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Claude Code │───▶│  UsageService│───▶│  SwiftUI     │
│  (~/.claude) │    │  (parse)     │    │  Views       │
└──────────────┘    └──────────────┘    └──────────────┘
```

### State Propagation

1. **File system event** → `FileWatcher` debounce (300ms) → `GitService.parseStatus()`
2. **Timer tick** (60s) → `GitHubService.fetchPRStatus()` → ViewModel update
3. **File change** (`~/.claude/projects/`) → `UsageService.parseUsage()` → ViewModel update
4. **ViewModel `@Published`** → SwiftUI re-renders affected views only

### Data Flow Principles

- **Unidirectional**: Data flows down from services → ViewModel → Views
- **Immutable snapshots**: Services return value types (structs, enums)
- **Debounced updates**: File system events coalesced to prevent thrashing
- **Lazy evaluation**: Only active repo tabs fetch data

---

## 4. Key Components

### 4.1 ShellRunner

**Purpose**: Safe, async wrapper around `Process` for shell command execution.

```swift
// GitPanelCore/Utilities/ShellRunner.swift

actor ShellRunner {
    /// Execute a shell command asynchronously with timeout
    func run(
        _ command: String,
        in directory: URL? = nil,
        timeout: TimeInterval = 30
    ) async throws -> ShellResult
    
    /// Cancel all running processes
    func cancelAll()
}

struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let duration: TimeInterval
    
    var succeeded: Bool { exitCode == 0 }
}
```

**Design decisions**:
- **Actor isolation**: Prevents concurrent process spawning races
- **Timeout enforcement**: Kills hung git processes (e.g., large repo status)
- **Structured concurrency**: Uses `withThrowingTaskGroup` for timeout
- **No shell injection**: Arguments passed as array, not interpolated strings

**Performance guard**:
```swift
// Throttle: max 3 concurrent shells per service
let semaphore = AsyncSemaphore(count: 3)
```

### 4.2 GitService

**Purpose**: All git operations — status, branch, log, diff, stash.

```swift
// GitPanelCore/Services/GitService.swift

@Observable
final class GitService {
    /// Cached repo metadata (HEAD, branch, upstream)
    private(set) var currentRepo: RepoMetadata?
    
    /// Raw status output, parsed incrementally
    private(set) var status: GitStatus = .empty
    
    /// Recent commits (last 20)
    private(set) var recentCommits: [GitCommit] = []
    
    // MARK: - Operations
    
    func refreshStatus() async throws
    func switchBranch(to name: String) async throws
    func commit(message: String) async throws
    func push() async throws
    func pull() async throws
    func stash() async throws
    func stashPop() async throws
    func fetch() async throws
    
    // MARK: - Parsing
    
    /// Parse `git status --porcelain=v2` incrementally
    func parseStatus(from output: String) -> GitStatus
    
    /// Parse `git branch -vv` for upstream tracking
    func parseBranchInfo(from output: String) -> BranchInfo
}
```

**Git operations mapped to commands**:

| Operation | Command | Notes |
|-----------|---------|-------|
| Status | `git status --porcelain=v2` | V2 format for machine parsing |
| Branch | `git branch -vv --no-color` | Includes upstream tracking |
| Log | `git log --oneline -20 --format=...` | Fixed window for perf |
| Diff | `git diff --stat` | Summary only, not full diff |
| Remote | `git remote -v` | Cached per session |

### 4.3 GitHubService

**Purpose**: GitHub API integration — PR status, checks, reviews.

```swift
// GitPanelCore/Services/GitService.swift

@Observable
final class GitHubService {
    private(set) var pullRequests: [PullRequest] = []
    private(set) var notifications: [GHNotification] = []
    
    // MARK: - PR Operations
    
    func fetchPRStatus(for repo: GitHubRepo) async throws
    func fetchCheckRuns(owner: String, repo: String, ref: String) async throws
    func fetchReviews(owner: String, repo: String, prNumber: Int) async throws
    
    // MARK: - Native GitHub CLI
    
    /// Uses `gh` CLI when available (faster than REST)
    func fetchPRsViaCLI(repo: String) async throws -> [PullRequest]
    
    /// Fallback: GitHub REST API v3
    func fetchPRsViaAPI(owner: String, repo: String) async throws -> [PullRequest]
}
```

**Authentication strategy**:
1. Check `gh auth token` (GitHub CLI)
2. Check `GITHUB_TOKEN` environment variable
3. Prompt user for PAT (stored in Keychain)

**Rate limiting**: Respect `X-RateLimit-*` headers, backoff on 429.

### 4.4 UsageService

**Purpose**: Track Claude Code usage from local files.

```swift
// GitPanelCore/Services/UsageService.swift

@Observable
final class UsageService {
    private(set) var todayUsage: DailyUsage = .empty
    private(set) var weeklyTrend: [DailyUsage] = []
    
    /// Watch ~/.claude/projects/*/usage.json
    func startWatching(projectPath: String) async
    
    /// Parse usage.json (token counts, cost, model breakdown)
    func parseUsageFile(at path: URL) throws -> UsageSnapshot
}
```

**Data source**: `~/.claude/projects/{project-hash}/usage.json`
```json
{
  "date": "2026-07-11",
  "totalTokens": 45200,
  "inputTokens": 38000,
  "outputTokens": 7200,
  "cost": 0.42,
  "model": "claude-sonnet-4-20250514"
}
```

### 4.5 FileWatcher

**Purpose**: Real-time file system monitoring via FSEvents.

```swift
// GitPanelCore/Utilities/FileWatcher.swift

import FSEvents

final class FileWatcher {
    private let stream: FSEventStreamRef
    private let callback: @Sendable ([FileEvent]) -> Void
    
    /// Debounce interval (prevents rapid-fire updates)
    var debounceInterval: TimeInterval = 0.3
    
    /// Start watching a directory tree
    func start(watching path: String) throws
    
    /// Stop and cleanup
    func stop()
    
    /// Pause/resume (e.g., during git operations)
    func setPaused(_ paused: Bool)
}

struct FileEvent: Sendable {
    let path: String
    let flags: FSEventStreamEventFlags
    let isDirectory: Bool
    
    var isGitMetadata: Bool {
        path.contains("/.git/") && !path.hasSuffix("/.git/HEAD")
    }
}
```

**Optimization**:
- Watch only `.git/` subdirectory (not entire repo)
- Ignore `.git/objects/` (loose objects — high churn)
- Coalesce events within debounce window

### 4.6 GitPanelViewModel

**Purpose**: Central state coordinator, owns all services.

```swift
// GitPanelCore/ViewModels/GitPanelViewModel.swift

@Observable
@MainActor
final class GitPanelViewModel {
    // MARK: - State
    
    var repoState: RepoState = .idle
    var repositories: [RepoMetadata] = []
    var selectedRepoIndex: Int = 0
    var error: UserFacingError?
    
    // MARK: - Child ViewModels
    
    let gitService: GitService
    let githubService: GitHubService
    let usageService: UsageService
    let fileWatcher: FileWatcher
    
    // MARK: - Actions
    
    func addRepository(at path: URL) async
    func removeRepository(at index: Int)
    func refreshAll() async
    func switchToRepo(at index: Int)
    
    // MARK: - Computed
    
    var currentRepo: RepoMetadata? {
        repositories[safe: selectedRepoIndex]
    }
    
    var statusSummary: String {
        switch repoState {
        case .idle: return "No repo"
        case .loading: return "Loading..."
        case .ready(let status): return status.shortSummary
        case .error(let err): return err.localizedDescription
        }
    }
}
```

---

## 5. State Machine

```
                    ┌─────────────┐
                    │    idle     │
                    └──────┬──────┘
                           │ addRepository()
                           ▼
                    ┌─────────────┐
                    │  loading    │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
       ┌────────────┐ ┌────────┐ ┌──────────┐
       │   ready    │ │ stale  │ │  error   │
       └──────┬─────┘ └───┬────┘ └────┬─────┘
              │            │           │
              │  file event│  retry    │ retry
              │            ▼           │
              │      ┌───────────┐    │
              │      │ reloading │    │
              │      └─────┬─────┘    │
              │            │          │
              └────────────┴──────────┘
                         │
                         ▼
                    (loop back)
```

### State Definitions

```swift
enum RepoState: Sendable {
    case idle                           // No repository loaded
    case loading                        // Initial load in progress
    case ready(GitStatus)               // Active, status current
    case stale(GitStatus, TimeInterval) // Status exists but age > 5s
    case error(UserFacingError)         // Recoverable error
    case reloading                      // Refresh in progress
}
```

### Transition Rules

| From | Trigger | To | Condition |
|------|---------|-----|-----------|
| `idle` | `addRepository()` | `loading` | — |
| `loading` | success | `ready` | — |
| `loading` | failure | `error` | — |
| `ready` | file event (`.git/`) | `stale` | debounce > 300ms |
| `ready` | timer (60s) | `stale` | — |
| `stale` | `refreshAll()` | `reloading` | — |
| `error` | `retry()` | `loading` | — |
| any | `removeRepository()` | `idle` | — |

---

## 6. Design Patterns

### 6.1 @Observable (Observation Framework)

```swift
// Instead of ObservableObject + @Published
@Observable
final class GitService {
    var status: GitStatus = .empty  // Automatically tracked
    var branch: String = "main"
}

// Views automatically update on any property change
struct StatusView: View {
    let service: GitService
    
    var body: some View {
        Text(service.branch)  // Re-renders when branch changes
    }
}
```

**Why @Observable over ObservableObject?**
- Fine-grained tracking (only re-renders for used properties)
- No `@Published` boilerplate
- Better performance for high-frequency updates
- Native to iOS 17+ / macOS 14+

### 6.2 async/await

```swift
// All service methods are async
func refreshStatus() async throws {
    let output = try await shellRunner.run("git", ["status", "--porcelain=v2"])
    self.status = parseStatus(from: output.stdout)
}

// Task management in ViewModel
func addRepository(at path: URL) async {
    self.repoState = .loading
    do {
        let metadata = try await gitService.loadRepository(at: path)
        self.repositories.append(metadata)
        self.repoState = .ready(metadata.status)
    } catch {
        self.repoState = .error(error.userFacing)
    }
}
```

### 6.3 Combine Debounce

```swift
// FileWatcher uses Combine for event coalescing
fileWatcher.events
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .sink { [weak self] events in
        Task { @MainActor in
            await self?.handleFileEvents(events)
        }
    }
    .store(in: &cancellables)
```

### 6.4 Actor Isolation

```swift
// ShellRunner is an actor — prevents concurrent process races
actor ShellRunner {
    private var runningProcesses: [Process] = []
    
    func run(_ command: String, args: [String]) async throws -> ShellResult {
        let process = Process()
        // ...
        runningProcesses.append(process)
        defer { runningProcesses.removeAll { $0 === process } }
        // ...
    }
}
```

### 6.5 Sendable Conformance

```swift
// All models are Sendable (value types)
struct GitStatus: Sendable {
    let staged: [FileChange]
    let unstaged: [FileChange]
    let untracked: [FileChange]
}

struct FileChange: Sendable {
    let path: String
    let status: ChangeStatus
}
```

---

## 7. Security Model

### 7.1 App Sandbox

```xml
<!-- GitPanel/Info.plist entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
```

### 7.2 Required Entitlements

| Entitlement | Purpose | Justification |
|-------------|---------|---------------|
| `app-sandbox` | macOS App Store requirement | Base security |
| `files.user-selected.read-only` | Open repo via file picker | User-initiated only |
| `network.client` | GitHub API calls | PR status fetching |
| `com.apple.security.temporary-exception.files.home-relative-path` | Access `~/.claude/` | Claude Code usage data |

### 7.3 Code Signing

```
Sign: true
Team ID: <DEVELOPER_TEAM_ID>
Signing Style: Automatic
Provisioning: App Store (Developer ID for distribution)
```

### 7.4 Security Boundaries

```
┌─────────────────────────────────────────────────────┐
│                   GitPanel App                      │
│  ┌───────────────────────────────────────────────┐  │
│  │  Sandboxed App Container                      │  │
│  │  - UserDefaults (per-app)                     │  │
│  │  - Keychain (entitled)                        │  │
│  │  - Temp files (auto-cleaned)                  │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │  User-Selected Paths (via NSOpenPanel)        │  │
│  │  - Git repositories (read-only)               │  │
│  │  - ~/.claude/projects/ (read-only)            │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │  Network (outbound only)                      │  │
│  │  - api.github.com (HTTPS)                     │  │
│  │  - github.com (HTTPS)                         │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

**Rules**:
1. Never write to user-selected directories
2. Never execute arbitrary user-provided shell commands
3. Git operations restricted to known commands (`git status`, `git log`, etc.)
4. GitHub tokens stored in Keychain, never logged
5. All network calls over HTTPS only

---

## 8. Performance Considerations

### 8.1 Branch Optimization

```swift
// Instead of: git status (scans entire tree)
// Use: git status --porcelain=v2 (machine-readable, incremental)

// For branch info, cache and update selectively:
func fetchBranchInfo() async throws {
    // Only refetch on:
    // 1. FileWatcher event in .git/HEAD
    // 2. Manual refresh
    // 3. Timer (60s max)
    
    let output = try await shell.run("git", ["branch", "-vv", "--no-color"])
    self.branchInfo = parseBranchInfo(from: output.stdout)
}
```

### 8.2 Incremental Parsing

```swift
// Parse git status line-by-line, not as whole string
func parseStatus(from output: String) -> GitStatus {
    var staged: [FileChange] = []
    var unstaged: [FileChange] = []
    
    for line in output.split(separator: "\n") {
        guard let change = parseStatusLine(line) else { continue }
        switch change.index {
        case 1: staged.append(change.file)
        case 2: unstaged.append(change.file)
        default: break
        }
    }
    
    return GitStatus(staged: staged, unstaged: unstaged, untracked: untracked)
}
```

### 8.3 Memory Management

| Strategy | Implementation |
|----------|---------------|
| Commit window | Last 20 commits only, lazy-load more |
| Event coalescing | 300ms debounce on file events |
| Weak references | ViewModel holds services weakly where possible |
| Actor throttling | Max 3 concurrent shell processes |
| Cache invalidation | On file event, invalidate only affected cache |

### 8.4 CPU Budget

```
Idle state:         < 0.1% CPU (FSEventStream callback only)
Active monitoring:  < 1% CPU (file event processing)
Refresh cycle:      < 5% CPU (git status parse)
GitHub fetch:       < 2% CPU (network I/O bound)
```

---

## 9. Testing Strategy

### 4-Tier Testing

```
┌─────────────────────────────────────────────────┐
│  Tier 4: Performance Tests                      │
│  - Memory usage over time                       │
│  - CPU during rapid file events                 │
│  - Git parse speed benchmarks                   │
│  (XCTest + Metrics)                             │
├─────────────────────────────────────────────────┤
│  Tier 3: Snapshot Tests                         │
│  - View rendering at different states           │
│  - Menu bar appearance (light/dark)             │
│  - Error states, loading states                 │
│  (swift-snapshot-testing)                       │
├─────────────────────────────────────────────────┤
│  Tier 2: Integration Tests                      │
│  - GitService + ShellRunner (real git repo)     │
│  - GitHubService + mock server                  │
│  - FileWatcher → GitService pipeline            │
│  (XCTest + temp directories)                    │
├─────────────────────────────────────────────────┤
│  Tier 1: Unit Tests                             │
│  - Status parsing (porcelain v2)                │
│  - Branch info parsing                           │
│  - State machine transitions                     │
│  - Model equality, hashing                      │
│  (XCTest)                                       │
└─────────────────────────────────────────────────┘
```

### Test Targets

```
GitPanelTests/               # Unit tests (Tier 1)
GitPanelIntegrationTests/    # Integration tests (Tier 2)
GitPanelSnapshotTests/       # Snapshot tests (Tier 3)
GitPanelPerformanceTests/    # Performance tests (Tier 4)
```

### Key Test Scenarios

| Scenario | Tier | Method |
|----------|------|--------|
| Parse empty git status | 1 | Assert `.empty` |
| Parse modified files | 1 | Assert file list matches |
| Parse branch with upstream | 1 | Assert tracking info |
| Repo state transitions | 1 | Assert state machine |
| File event triggers refresh | 2 | Mock FSEventStream |
| GitHub rate limit handling | 2 | Mock HTTP 429 |
| View renders loading state | 3 | Snapshot comparison |
| Menu bar icon updates | 3 | Snapshot comparison |
| Memory stays under 50MB | 4 | Instruments tracking |
| CPU idle < 0.1% | 4 | CPU metric collection |

---

## 10. Directory Structure

```
GitPanel/
├── ARCHITECTURE.md                 # This file
├── README.md
├── GitPanel.xcodeproj/
│   └── project.pbxproj
│
├── GitPanelCore/                   # Shared library
│   ├── Package.swift               # SPM manifest (if applicable)
│   ├── Sources/
│   │   ├── Models/
│   │   │   ├── GitStatus.swift
│   │   │   ├── GitCommit.swift
│   │   │   ├── BranchInfo.swift
│   │   │   ├── RepoMetadata.swift
│   │   │   ├── PullRequest.swift
│   │   │   ├── UsageSnapshot.swift
│   │   │   ├── FileChange.swift
│   │   │   └── RepoState.swift
│   │   ├── Services/
│   │   │   ├── GitService.swift
│   │   │   ├── GitHubService.swift
│   │   │   └── UsageService.swift
│   │   ├── ViewModels/
│   │   │   └── GitPanelViewModel.swift
│   │   └── Utilities/
│   │       ├── ShellRunner.swift
│   │       ├── FileWatcher.swift
│   │       ├── GitHubAuth.swift
│   │       ├── KeychainHelper.swift
│   │       └── Extensions/
│   │           ├── String+Git.swift
│   │           ├── URL+Helpers.swift
│   │           └── Date+Relative.swift
│   └── Tests/
│       ├── UnitTests/
│       │   ├── GitStatusParserTests.swift
│       │   ├── BranchInfoParserTests.swift
│       │   └── RepoStateTests.swift
│       ├── IntegrationTests/
│       │   ├── GitServiceIntegrationTests.swift
│       │   ├── GitHubServiceIntegrationTests.swift
│       │   └── FileWatcherIntegrationTests.swift
│       ├── SnapshotTests/
│       │   ├── MenuBarViewSnapshotTests.swift
│       │   └── StatusViewSnapshotTests.swift
│       └── PerformanceTests/
│           ├── ParsePerformanceTests.swift
│           └── MemoryUsageTests.swift
│
├── GitPanel/                       # macOS app target
│   ├── Sources/
│   │   ├── App/
│   │   │   ├── GitPanelApp.swift        # @main, MenuBarExtra
│   │   │   └── AppDelegate.swift        # NSApplicationDelegate
│   │   ├── Views/
│   │   │   ├── MenuBar/
│   │   │   │   ├── MenuBarView.swift
│   │   │   │   ├── StatusBarButton.swift
│   │   │   │   └── MenuBarMenu.swift
│   │   │   ├── Dashboard/
│   │   │   │   ├── RepoDashboardView.swift
│   │   │   │   ├── StatusSummaryView.swift
│   │   │   │   ├── BranchPickerView.swift
│   │   │   │   └── CommitHistoryView.swift
│   │   │   ├── GitHub/
│   │   │   │   ├── PRStatusView.swift
│   │   │   │   ├── CheckRunView.swift
│   │   │   │   └── NotificationBadge.swift
│   │   │   ├── Usage/
│   │   │   │   ├── UsageInsightsView.swift
│   │   │   │   ├── TokenChartView.swift
│   │   │   │   └── CostDisplayView.swift
│   │   │   └── Shared/
│   │   │       ├── ErrorBanner.swift
│   │   │       ├── LoadingSpinner.swift
│   │   │       └── EmptyStateView.swift
│   │   └── Helpers/
│   │       ├── MenuBarAppearance.swift
│   │       ├── UserDefaults.swift
│   │       └── NotificationManager.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   │   ├── AppIcon.appiconset/
│   │   │   ├── StatusBarIcons/
│   │   │   └── Colors/
│   │   ├── Info.plist
│   │   └── GitPanel.entitlements
│   └── GitPanel.xcodeproj/
│
└── Scripts/
    ├── build.sh                    # CI build script
    ├── test.sh                     # Run all tests
    └── lint.sh                     # SwiftLint
```

---

## Appendix: Quick Reference

### Git Commands Used

| Command | Purpose | Frequency |
|---------|---------|-----------|
| `git status --porcelain=v2` | File status | On file event |
| `git branch -vv` | Branch + upstream | On file event |
| `git log --oneline -20` | Recent commits | On refresh |
| `git diff --stat` | Change summary | On demand |
| `git remote -v` | Remote URLs | Once per repo |
| `git rev-parse HEAD` | Current SHA | On file event |
| `git config user.name` | Author name | Once per repo |

### External Dependencies

| Dependency | Purpose | Required? |
|------------|---------|-----------|
| `gh` (GitHub CLI) | Auth, PR operations | Optional (REST fallback) |
| `git` | All git operations | Yes |

### Configuration Keys

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `watchedRepos` | `[String]` | `[]` | Paths to monitored repos |
| `refreshInterval` | `TimeInterval` | `60` | Timer-based refresh |
| `debounceInterval` | `TimeInterval` | `0.3` | File event coalescing |
| `showNotifications` | `Bool` | `true` | PR status notifications |
| `theme` | `String` | `"auto"` | Light/dark/auto |

---

*Last updated: 2026-07-11*  
*Architecture version: 1.0.0*
