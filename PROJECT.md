# Project: GitPanel macOS Menu Bar App

## Architecture
- **GitPanel Target**: Executable app target containing only the entry point (`main.swift`) which instantiates the `AppDelegate` and starts the app runtime.
- **GitPanelCore Target**: Library target containing the SwiftUI views (`BranchListView`, `SettingsView`, etc.), `GitPanelViewModel`, and services (`GitService`, `ShellRunner`, `FileWatcher`, `AppSettings`, `RepoManager`, `UsageService`, `GitHubService`).
- **Data Flow**:
  - `FileWatcher` detects file changes in the workspace and feeds event notifications via an `AsyncStream` to trigger `GitService` refreshes.
  - `ShellRunner` executes external subprocesses (`git`, `gh`, `sqlite3`) and returns process outputs.
  - `GitService` processes output using Swift Concurrency, returning immutable snapshots (`Sendable`) to update `GitState` properties on the `@MainActor`.
  - `@Observable` singletons (`AppSettings`, `RepoManager`) and `GitState` are isolated to `@MainActor` to ensure thread-safety.

## Code Layout
- `Package.swift` - Swift Package Manager configuration.
- `Sources/GitPanel/` - Application entry point (`main.swift`).
- `Sources/GitPanelCore/` - Shared business logic, UI views, services, and models.
  - `Services/` - Services (ShellRunner, GitService, FileWatcher, RepoManager, etc.)
  - `Views/` - SwiftUI views (BranchListView, FileListView, SettingsView, etc.)
- `Tests/GitPanelTests/` - Unit tests for parsing and business logic.
- `Resources/` - Assets, plists, and data files (`model_prices.json`).

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|---|---|---|---|
| M1 | Initial Audit & Build Verification | Build and run existing tests, inspect code layout and duplication | None | DONE |
| M2 | Direct Process Spawning | Refactor `ShellRunner` to execute processes directly without zsh wrapper (R1) | M1 | DONE |
| M3 | FileWatcher Safety & Monitoring | Fix callback memory safety, watch workspace root, support MERGE_HEAD (R2) | M1 | DONE |
| M4 | UI State, Fault Tolerance & HIG | ViewModel refresh fault tolerance, stored properties, remove shortcut hijacking, HIG polish (R3, R4, R6, R9) | M1 | DONE |
| M5 | Multi-Repository Support | Implement Repo history storage and switching in menu bar (R5) | M1 | DONE |
| M6 | Thread Safety & Concurrency | Isolate singletons to `@MainActor`, ensure Sendable snapshots, prevent overlapping git commands (R8) | M2, M3, M5 | DONE |
| M7 | SPM Restructuring & Resource Trimming | Cleanup duplicates, move views/services to GitPanelCore, trim model_prices.json, quick binary resolve (R7, R10) | M1 | DONE |
| M8 | Comprehensive Unit Testing | Add tests for Porcelain V2, numstat, and SQLite logs in `Tests/GitPanelTests` (R7) | M1 | DONE |
| M9 | Final Verification & Hardening | Final verification of build, tests, and thread safety under load | M2, M3, M4, M5, M6, M7, M8 | DONE |

## Interface Contracts
### `ShellRunner` ↔ Services
- Method: `run(bin: String, args: [String], Cwd: String?) async throws -> ProcessResult`
- Returns a struct containing stdout, stderr, and termination status. Uses cooperative cancellation and does not block threads.

### `FileWatcher` ↔ `GitService` / `ViewModel`
- Method: `startWatching(path: String) -> AsyncStream<FileWatcherEvent>`
- Non-blocking callback stream for monitoring directory updates safely.

### `RepoManager` ↔ View Models / Views
- Exposes list of repositories and the currently active repository on `@MainActor`.
- Triggers notifications or updates when the active repository changes.
