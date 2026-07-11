# Original User Request

## Initial Request — 2026-07-09T06:35:32+05:30

Improve the GitPanel macOS menu bar application to make it production-grade by resolving memory safety issues, refactoring shell command execution, implementing proper Swift concurrency isolation, adding multi-repo support, removing global shortcut hijacking, and introducing unit tests.

Working directory: /Users/vaibhavkakar/Desktop/Gitpanel
Integrity mode: development

## Requirements

### R1. Direct Process Spawning (No Shell Wrapper)
Refactor `ShellRunner` to directly execute binaries (such as `git`, `gh`, or `sqlite3`) using argument arrays `[String]` instead of spawning zsh login shells (`/bin/zsh -cl`). Remove manual string-based shell escaping. Use `process.terminationHandler` and `withCheckedThrowingContinuation` to suspend tasks non-blockingly, avoiding thread starvation in the cooperative thread pool.

### R2. FileWatcher Memory Safety & Working Tree Monitoring
- **Fix Callback Memory Safety**: Resolve the memory layout mismatch in `fileWatcherCallback` where `eventPaths` is cast to a C-string pointer while the `kFSEventStreamCreateFlagUseCFTypes` flag is set (causing crashes on file changes). Either cast to `CFArray` or remove the `UseCFTypes` flag. Prevent dangling pointer crashes by wrapping callbacks via an `AsyncStream` and a retained `Sendable` box.
- **Monitor Working Tree**: Modify `FileWatcher` to watch the workspace root directory instead of only the `.git` folder so that IDE file edits are detected. Configure the stream to ignore heavy directories like `.git`, `node_modules`, and `.build`.
- **Detect Merge State**: Add a check for `.git/MERGE_HEAD` in `detectRepoState` to support the missing `.merging` state.

### R3. Fault-Tolerant ViewModel Refresh
Decouple tasks inside `GitPanelViewModel.refresh()` so that optional components (such as GitHub PR checks via `gh` or token calculation via `UsageService`) that fail due to missing authorization or offline state do not block or crash the core Git status refresh.

### R4. Active UI State & Stored Properties
Convert `GitState` variables `stagedCount`, `unstagedCount`, `untrackedCount`, and `conflictCount` from hardcoded `0` computed getters into stored variables. Assign the parsed values from the porcelain V2 results during updates so that the `FileStatsView` chips display correctly in the UI. Populate branch ahead/behind indicators within the branch list.

### R5. Multi-Repository Support
Implement support for managing and switching between multiple repositories. Store a history of opened repositories in `UserDefaults`, allowing the user to select the active repository from a list in the menu bar and remove repositories from the history.

### R6. Remove Global Keyboard Shortcut Hijacking
Remove the system-wide key monitoring (`NSEvent.addGlobalMonitorForEvents`) for `Cmd+R` and `Cmd+Enter` which intercepts shortcuts in other apps (like Xcode, Slack, and browsers) when GitPanel is not active. Restrict keyboard shortcuts to when the popover is focused.

### R7. Swift Package Manager Restructuring & Unit Testing
Split the target layout in `Package.swift` into a library target (`GitPanelCore` containing view models, services, models, and views), an executable target (`GitPanel` containing only `main.swift`), and a test target (`GitPanelTests`). Implement a comprehensive unit test suite in `Tests/GitPanelTests` that tests Git Porcelain V2 parsing, numstat parsing, and SQLite log parsing.

### R8. Thread Safety & Swift Concurrency Compliance
- Isolate `@Observable` singletons (`AppSettings` and `RepoManager`) and `GitState` to the `@MainActor`.
- Ensure all mutations of UI state properties occur on the `@MainActor` (currently `GitService.updateState` mutates `GitState` directly on background threads, violating thread safety). Have background services return immutable `Sendable` snapshots to be safely applied on the main thread.
- Guard ViewModel mutation methods (like `checkout` or `commit`) so that overlapping git commands cannot be executed concurrently, avoiding `.git/index.lock` write collision conflicts.

### R9. SwiftUI & HIG UI/UX Polish
- Move `@State` variables (like `isRowHovered`) out of computed view properties and place them in the correct view struct scopes.
- Correct redundant stacked navigation headers/back buttons (e.g. in `RepositoryInfoView`).
- Make the Environment Menu navigation route reachable from the main view (e.g. by clicking the repository header card).
- Present `RepoPicker` file panel asynchronously (`panel.begin`) instead of using the blocking thread-freezing `panel.runModal()`.
- Align typography with macOS Human Interface Guidelines (HIG) by restricting monospaced design to paths, hashes, and diff statistics, using standard system fonts (San Francisco) for standard labels and control buttons.

### R10. Resource Trimming, Fallbacks & Clean Up
- Resolve binary paths (`git`, `gh`) at startup using quick `FileManager` checks instead of blocking subprocess calls to `which`.
- Trim `model_prices.json` to only contain Claude models (reducing file size from 1.6MB to <1KB).
- Add support for loading `model_prices.json` from the current working directory as a fallback when running in local development mode (`swift run`).
- Remove dead unused files like `ChangesRow.swift` and correct the macOS target version in `README.md` to macOS 14.0+.

## Verification Plan

### Automated Tests
- Command: `swift test` must build and pass successfully.
- Command: `swift build` must complete without errors or warnings.

### Manual Verification
- Verify that `ShellRunner.swift` has no remaining calls to `/bin/zsh` or `-cl`.
- Verify the app launches, allows adding and switching between multiple git repositories, and updates UI without memory leaks or main-thread freezes.
- Verify that simulating a GitHub CLI failure or missing SQLite file does not freeze or block the menu bar icon from updating with Git status.
- Verify that runtime thread-safety checkers (like Xcode's Main Thread Checker or Swift Concurrency runtime checks) report zero violations during app operations.

## Acceptance Criteria

### Compilation, Testing & Architecture
- [ ] `swift build` completes without errors or warnings.
- [ ] `swift test` completes successfully with a new test suite coverage.
- [ ] The `Package.swift` is split into `GitPanelCore` library, `GitPanel` executable, and `GitPanelTests` target.

### Code Quality & Security
- [ ] Dynamic command execution via zsh subshells and manual shell escaping are completely removed.
- [ ] Unsafe memory casting in `fileWatcherCallback` is resolved, and FSEvent callbacks run crash-free.
- [ ] Weak references are used for all self-referencing closures in `FileWatcher`, view models, and `AppDelegate` to prevent retain cycles.
- [ ] System-wide global shortcut hijacking is removed.

### SwiftUI & Concurrency Integrity
- [ ] `@State` variables are removed from computed view properties and placed in proper view scopes.
- [ ] All observable class mutations are thread-safe and isolated to `@MainActor`.
- [ ] `model_prices.json` is reduced to <1KB and loads correctly both when run as a standalone binary via `swift run` and when built into the `.app` bundle.
- [ ] Monospaced fonts are restricted only to paths, hashes, and diff statistics, utilizing standard SF fonts elsewhere.

### Functional Resiliency
- [ ] GitHub PR service errors or UsageService file-access errors do not cause `GitPanelViewModel.refresh()` to fail the core Git state refresh.
- [ ] FileStatsView chips display correct staged, unstaged, untracked, and conflict counts when changes occur.
- [ ] The app successfully stores a history of opened repositories in UserDefaults and lets the user choose their active repository.
