# GitPanel v2 — AI Developer Command Center
## Detailed Roadmap for AI-Assisted Development

***

## What CodexBar Brings to GitPanel

CodexBar by steipete is a native macOS menu bar app specifically built to monitor OpenAI Codex CLI sessions — it covers process detection, token counting, and session timing for Codex.  Its architecture (Swift Package, `WidgetExtension`, modular `Sources`) maps perfectly onto GitPanel's existing Swift codebase.  Absorbing CodexBar means you get **proven Codex CLI process detection logic** you don't have to build from scratch, plus its Sparkle-based auto-update mechanism (`appcast.xml`) and widget support as a bonus. 

The concrete things to port from CodexBar:

- **Process scanner** — scans running processes for `codex` CLI binary, reads its working directory and parent PID
- **Session timer** — tracks wall-clock time from process spawn to termination
- **Token parser** — reads Codex CLI's stdout/log output and parses token usage JSON
- **WidgetExtension** — macOS widget showing AI status on desktop/notification center 

***

## Release Plan

### v1.1 — Codex Integration (Immediate, ~2 weeks)

**Goal:** Absorb CodexBar into GitPanel as the "Codex Provider."

Implementation tasks:
1. Create `Sources/GitPanel/Providers/CodexProvider.swift` — wrap CodexBar's process detection as a `AIProviderProtocol` conforming type
2. Rename existing Claude-specific monitor to `ClaudeProvider.swift` under the same protocol
3. Define `AIProviderProtocol`:
```swift
protocol AIProviderProtocol {
    var name: String { get }
    var isRunning: Bool { get }
    var sessionDuration: TimeInterval? { get }
    var tokenUsage: TokenUsage? { get }
    var workspacePath: URL? { get }
    func startMonitoring()
    func stopMonitoring()
}
```
4. Port CodexBar's `WidgetExtension` as an optional add-on target in `Package.swift` 
5. Menu bar icon should reflect the active provider: `⚡` for Codex, `◆` for Claude, etc.

**Acceptance criteria:**
- `codex` process detected within 2 seconds of launch
- Session time shown accurately in menu bar popover
- GitPanel's existing Git status panel unaffected

***

### v1.2 — Multi-Agent Engine (~3 weeks)

**Goal:** Full provider abstraction. Support Claude Code, Codex CLI, Gemini CLI, Aider, OpenCode simultaneously.

Implementation tasks:

1. `AIEngine.swift` — orchestrator that polls all registered providers every 5 seconds using `DispatchSourceTimer`
2. Provider registry via `AIProviderRegistry` — dynamically loads `[any AIProviderProtocol]`
3. Detection strategy per provider:

| Provider | Detection Method | Log Source |
|---|---|---|
| Claude Code | `ps aux` grep `claude` | `~/.claude/logs/` |
| Codex CLI | Process scan for `codex` binary | stdout pipe / temp log |
| Gemini CLI | `ps aux` grep `gemini` | `~/.gemini/logs/` |
| Aider | `ps aux` grep `aider` | `.aider.chat.history.md` |
| OpenCode | `opencode.json` in repo root  | IPC socket if available |

4. `MultiAgentDashboardView.swift` — SwiftUI List showing all providers with color-coded status dots
5. Use `NSWorkspace.shared.runningApplications` as primary source; fallback to `Process` + `ps` for CLI tools

***

### v1.3 — Token & Cost Tracking (~3 weeks)

**Goal:** Real-time token usage and cost estimation without any external API calls (fully local).

Implementation tasks:

1. `TokenTracker.swift` — parses provider-specific log formats:
   - Claude: reads `~/.claude/logs/*.jsonl`, extracts `usage.input_tokens` + `usage.output_tokens`
   - Codex: port CodexBar's existing token parser 
   - Gemini: parse `~/.gemini/` session logs
2. `CostEngine.swift` — static pricing table (user-editable in Settings):
```swift
struct ModelPricing {
    let inputPer1M: Double   // USD
    let outputPer1M: Double
}
```
3. Persistent store: `UserDefaults` for daily/monthly rolling totals, keyed by `yyyy-MM-dd`
4. `SpendingDashboardView.swift`:
   - Today / This Week / This Month cards
   - Per-provider breakdown
   - Bar chart using Swift Charts (`import Charts`) — no third-party dependency needed
5. **Context Window Monitor**: parse log for `context_tokens_used` / `context_window_size`, show `████████░░ 82%` progress bar using SwiftUI `ProgressView` with custom style
6. Warn when context > 80% via `UNUserNotificationCenter`

***

### v1.4 — Repository Dashboard + GitHub Integration (~4 weeks)

**Goal:** Make GitPanel the single pane of glass for repository health.

Implementation tasks:

1. `GitEngine.swift` (likely already partially exists ) — extend with:
   - `git log --oneline -20` for recent commits
   - `git stash list | wc -l` for stash count
   - `git diff --name-only` for modified files list
   - `git ls-files --others --exclude-standard` for untracked count
   - `git status --porcelain=v2 --branch` for ahead/behind
2. `GitHubIntegration.swift` — GitHub REST API v3 client (no SDK, raw `URLSession`):
   - `GET /repos/{owner}/{repo}/pulls?state=open` — open PRs
   - `GET /repos/{owner}/{repo}/statuses/{sha}` — CI status
   - `GET /issues?assignee=@me&state=open` — assigned issues
   - OAuth token stored in macOS Keychain via `Security.framework`
3. `PRStatusView.swift` — show: PR title, CI badge (✅/❌/🔄), review requests, merge conflict indicator
4. `IssueTrackerView.swift` — list with `NSWorkspace.open(url)` on click to open in browser
5. Poll GitHub API every 60 seconds; respect `X-RateLimit-Remaining` header to avoid 403s

***

### v1.5 — Build & Test Monitor (~3 weeks)

**Goal:** Watch build and test processes without any configuration.

Implementation tasks:

1. `BuildMonitor.swift` — watch for active processes:
   - `xcodebuild` — parse `-destination` flag for context
   - `swift build` — watch `~/.build/` for `build.db` modification time
   - `npm run` / `npm test` — parse `package.json` scripts
   - `cargo build` / `cargo test`
   - `go build` / `go test`
2. `BuildStatusView.swift`:
   - Running (spinner) / Succeeded (✅) / Failed (❌)
   - Duration since start
   - Last exit code
3. For `xcodebuild`: tail its output pipe and scan for `** BUILD SUCCEEDED **` or `** BUILD FAILED **`
4. `TestDashboardView.swift`:
   - Parse `xcodebuild test` output for `Test Suite` pass/fail counts
   - For `npm test` / `jest` — parse stdout for `X passed, Y failed`
   - Show coverage % if `lcov.info` or `coverage-summary.json` present in repo

***

### v1.6 — Commit Assistant + Diff Preview (~2 weeks)

**Goal:** AI-powered commit workflow without leaving the menu bar.

Implementation tasks:

1. `CommitAssistant.swift`:
   - Run `git diff --staged` to capture staged diff
   - Send diff to user's configured AI provider (Claude/OpenAI/Gemini) via their API
   - Prompt template: `"Generate a conventional commit message for this diff: {diff}. Format: type(scope): description"`
   - Display suggested message in editable `TextEditor`
   - "Commit" button runs `git commit -m "{message}"`
2. `DiffPreviewView.swift`:
   - List changed files from `git status --porcelain`
   - On file selection, show `git diff {file}` output in a syntax-highlighted `NSTextView`
   - Use `NSAttributedString` with regex-based coloring (green for `+`, red for `-`) — no web views
3. API key management: stored in Keychain, never written to disk or logs

***

### v1.7 — MCP Server Monitor (~2 weeks)

**Goal:** Show connected MCP servers and their health, useful since you heavily use MCP tools. 

Implementation tasks:

1. Read MCP config from `~/.claude/claude_desktop_config.json` (Claude's MCP server list)
2. `MCPServerMonitor.swift` — for each server:
   - HTTP `GET /health` if server exposes HTTP endpoint
   - TCP socket connect check for socket-based servers
   - Parse server process from `ps aux`
3. `MCPStatusView.swift`:
   - Server name + type icon (🗄 Postgres, 📁 Filesystem, 🐙 GitHub, etc.)
   - Status dot: green = connected, red = error, yellow = slow (> 500ms latency)
   - "Restart" button: sends `SIGTERM` then re-spawns using the command from config

***

### v1.8 — AI Timeline (~3 weeks)

**Goal:** Reconstruct what the AI agent actually did in a session.

Implementation tasks:

1. `TimelineEngine.swift` — correlates events across sources:
   - Git log timestamps → "N files modified", "Commit created"
   - Build monitor events → "Build started/finished"
   - AI log timestamps → "Prompt submitted"
   - Test runner output → "Tests passed/failed"
2. `TimelineEvent` model:
```swift
struct TimelineEvent: Identifiable {
    let id: UUID
    let timestamp: Date
    let type: EventType  // .prompt, .filesModified, .buildSucceeded, .testsPassed, .commit, .push
    let description: String
    let metadata: [String: String]
}
```
3. `TimelineView.swift` — vertical list with connecting line, time labels on left, event cards on right; SwiftUI `ScrollView` with `LazyVStack`
4. Persist timeline to `~/.gitpanel/timeline.jsonl` — append-only, one JSON object per line

***

### v2.0 — Plugin Architecture + Spending Dashboard (~6 weeks)

**Goal:** Allow community plugins, reach feature parity with a full CI/CD dashboard.

Implementation tasks:

1. Plugin protocol via `dylib` loading or XPC services:
```swift
protocol GitPanelPlugin {
    var identifier: String { get }
    var displayName: String { get }
    var version: String { get }
    func provideStatusItems() -> [StatusItem]
    func provideViews() -> [AnyView]
}
```
2. First-party plugins to ship in v2.0:
   - **Docker** — query Docker socket at `/var/run/docker.sock` for running containers
   - **GitHub Actions** — `GET /repos/{owner}/{repo}/actions/runs?per_page=5`
   - **Linear** — GraphQL API for assigned issues
   - **Vercel** — deployments API
3. `SpendingDashboardView.swift` — Swift Charts bar chart, monthly view, per-provider color coding, exportable as CSV
4. `TODOScanner.swift` — run `grep -rn "TODO\|FIXME\|BUG\|HACK\|XXX"` in repo root, group by type, show count badges
5. `ReleaseNotesGenerator.swift` — `git log {prev_tag}..HEAD --oneline`, send to AI, format as changelog

***

## Architecture Modules Summary

```
GitPanel/
├── Sources/
│   ├── Core/
│   │   ├── AppDelegate.swift
│   │   ├── MenuBarController.swift
│   │   └── SettingsStore.swift          // UserDefaults + Keychain
│   ├── Git/
│   │   ├── GitEngine.swift
│   │   ├── GitHubIntegration.swift
│   │   └── CommitAssistant.swift
│   ├── AI/
│   │   ├── AIEngine.swift               // Orchestrator
│   │   ├── AIProviderProtocol.swift
│   │   ├── ClaudeProvider.swift
│   │   ├── CodexProvider.swift          // ← from CodexBar
│   │   ├── GeminiProvider.swift
│   │   ├── AiderProvider.swift
│   │   └── TokenTracker.swift
│   ├── Build/
│   │   ├── BuildMonitor.swift
│   │   └── TestDashboard.swift
│   ├── MCP/
│   │   └── MCPServerMonitor.swift
│   ├── Timeline/
│   │   └── TimelineEngine.swift
│   ├── Plugins/
│   │   ├── GitPanelPlugin.swift         // Protocol
│   │   └── PluginManager.swift
│   └── UI/
│       ├── MultiAgentDashboardView.swift
│       ├── SpendingDashboardView.swift
│       ├── PRStatusView.swift
│       ├── DiffPreviewView.swift
│       ├── MCPStatusView.swift
│       └── TimelineView.swift
└── WidgetExtension/                     // ← from CodexBar
```

***

## Performance Constraints (Per Feature)

| Module | Polling Interval | Max Memory Budget |
|---|---|---|
| Git Engine | 5 seconds | 5 MB |
| AI Provider scan | 5 seconds | 3 MB |
| GitHub API | 60 seconds | 2 MB |
| Build Monitor | 2 seconds (active), 10s (idle) | 4 MB |
| MCP Monitor | 30 seconds | 2 MB |
| Token Tracker | On log file change (`FSEvents`) | 3 MB |
| Total app target | — | < 50 MB |

Use `FSEvents` via `DispatchSource.makeFileSystemObjectSource` for log watching instead of polling wherever possible — this is zero-cost when files aren't changing and far more efficient than timers.

***

## Priority Order for Next 3 Releases

1. **v1.1** — CodexBar integration (immediate value, small scope, reuses proven code from [steipete/CodexBar](https://github.com/steipete/CodexBar))
2. **v1.3** — Token & Cost Tracking (highest user demand for AI devs, differentiates from all Git-only tools)
3. **v1.4** — GitHub Integration (PR status + issues is what keeps developers checking GitHub 20 times a day — put it in the menu bar instead)
