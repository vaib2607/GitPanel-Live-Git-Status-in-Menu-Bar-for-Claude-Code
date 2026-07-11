# GitPanel Test Infrastructure

This document outlines the test architecture, target layout, environment mocking, and verification setup implemented for the GitPanel project.

## 1. Target Layout Split

To support testable imports and modular code separation, the GitPanel project has been restructured from a single executable target into three distinct SPM targets:

1. **`GitPanelCore` (Library)**: Holds all application services, view models, states, views, and the core application delegate (`AppDelegate`).
2. **`GitPanel` (Executable)**: Contains only `main.swift` and a blanked out `AppDelegate.swift` which link against `GitPanelCore` to launch the AppKit status bar application.
3. **`GitPanelTests` (Test Target)**: Direct XCTest-based test target that imports `GitPanelCore` using `@testable import GitPanelCore` to execute unit, integration, and E2E scenario tests.

## 2. 4-Tier Test Architecture

The test suite covers the 9 core features of GitPanel across four distinct tiers:

### Tier 1: Feature Coverage (Happy Path)
- **Feature 1 (Direct Process Spawning)**: Tests array-based process execution, non-blocking asynchronous continuation, command failed errors, special characters safety, and exit codes.
- **Feature 2 (FileWatcher & Merge State)**: Tests FSEvent stream monitoring of workspace roots, CFArray callback safety, directory exclusions, `AsyncStream` callback safety, and `.merging` state.
- **Feature 3 (Fault-Tolerant Refresh)**: Tests success under healthy optional services, offline/missing GitHub CLI, permission-denied SQLite database, malformed Claude logs JSONL, and banner notifications.
- **Feature 4 (Active UI State)**: Tests count property population, branch details, detached HEAD branches, ahead/behind indicators, and upstream presence.
- **Feature 5 (Multi-Repository Support)**: History appending, user defaults persistence, switching active repository, removal from history, and duplicate prevention.
- **Feature 6 (Keyboard Shortcut Behavior)**: Monitor setup, event routing, modifier matching, and debouncing.
- **Feature 7 (Thread Safety & Isolation)**: ViewModel MainActor isolation, singleton isolation, Sendable snapshots, operation guards, and settings mutations.
- **Feature 8 (SwiftUI HIG UX Polish)**: Route navigation, async file picker, view state location, typography constraints, and transient state.
- **Feature 9 (Resource Trimming & Fallbacks)**: Startup binary check, price database CWD fallback, Claude-only filtering, dead view exclusion, and missing file fallback.

### Tier 2: Boundary & Corner Cases
- Focuses on failure modes, error messages, maximum integers, furious file system changes, nested paths, malformed files, detached HEAD hash checkout, history size capping (20), deleted repos, and directory validation.

### Tier 3: Cross-Feature Combinations
- Simulates concurrent interactions:
  - Repository switching while background process is running (cancellation verification).
  - Rapid FileWatcher updates triggering sequential refreshes.
  - Multi-repo switching changing FSEvent directories.
  - Overlapping Git operations blocking refreshes.
  - Optional service failures preserving the last known Git state.

### Tier 4: Real-World Application Scenarios (E2E Journeys)
- **Scenario 1**: Fresh Setup and Repo Initialisation.
- **Scenario 2**: Code Editing and Staging Workflow.
- **Scenario 3**: Commit and Push Workflow.
- **Scenario 4**: Multi-Repo Switching and History Clean up.
- **Scenario 5**: Conflict Resolution State.

## 3. Genuine Environment Mocking

The test suite is built on genuine logic without code mock facades:
1. **Git Operations**: Created real temporary directories, initializing Git repositories using `git init`, committing files, checking out commits, and modifying files to verify Porcelain V2 outputs.
2. **Process Mocking (PATH Precedence)**: Custom temporary `bin/` folders are injected into the environment `PATH` containing bash scripts to mock CLI tools like `gh` and `sqlite3` dynamically.
3. **Environment Isolation (HOME Override)**: The `HOME` environment variable is redirected to a temporary directory before running tests to isolate files (like Cursor databases and Claude project logs) from polluting or accessing the user's actual settings.
