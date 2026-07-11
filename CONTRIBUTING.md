# Contributing to GitPanel

Thank you for your interest in contributing to GitPanel! This guide will help you get started.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Architecture Overview](#architecture-overview)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

---

## Getting Started

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 16.0+ (for Swift/iOS builds) or VS Code with Swift extension
- Swift 6.0+
- Git 2.40+
- [Homebrew](https://brew.sh) (recommended for installing dependencies)

### Cloning the Repository

```bash
git clone https://github.com/your-org/GitPanel.git
cd GitPanel
```

### Building the Project

**Using Xcode:**
```bash
open GitPanel.xcodeproj
# Select your target destination and press Cmd+R
```

**Using Swift Package Manager:**
```bash
swift build
```

---

## Development Setup

### Xcode vs VS Code

| Feature | Xcode | VS Code |
|---|---|---|
| Primary Use | iOS/macOS builds, Interface Builder | Swift packages, extensions, backend |
| Recommended For | Full app development, profiling | Package-level work, code reviews |
| Extensions | Built-in Instruments | Swift Language, SourceKit-LSP |

Use **Xcode** for UI work, device simulation, and profiling. Use **VS Code** for faster iteration on business logic and Swift packages.

### Dependencies

```bash
# Install any brew dependencies
brew bundle

# Resolve Swift packages
swift package resolve
```

---

## Code Style

### Swift Conventions

- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use `camelCase` for variables, functions, and methods
- Use `PascalCase` for types, protocols, and enums
- Prefer `struct` over `class` unless reference semantics are required
- Use `guard` for early exits and preconditions
- Mark thread-safety annotations (`@MainActor`, `Sendable`) where applicable

### Formatting

- 4-space indentation (no tabs)
- Max line length: 120 characters
- Blank line between function definitions
- No trailing whitespace

```swift
// Good
func fetchRepository(at url: URL) async throws -> Repository {
    let data = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(Repository.self, from: data.0)
}

// Bad
func fetchRepository(at url: URL)async throws->Repository{let data = try await URLSession.shared.data(from: url);return try JSONDecoder().decode(Repository.self, from: data.0)}
```

### Naming

- Use descriptive, intention-revealing names
- Prefix delegate protocols with the delegating type (e.g., `RepositoryDetailViewDelegate`)
- Use past-tense for boolean properties that describe state (e.g., `hasLoaded`)
- Use `-ed` / `-ing` suffixes for delegate methods based on timing

---

## Architecture Overview

### Module Structure

```
GitPanel/
├── Sources/
│   ├── App/              # App entry point, lifecycle
│   ├── Features/         # Feature modules (RepoList, DiffViewer, etc.)
│   ├── Core/             # Shared utilities, extensions
│   ├── Models/           # Data models, DTOs
│   ├── Services/         # API clients, persistence, networking
│   └── UI/               # Reusable UI components
├── Tests/
│   ├── UnitTests/
│   ├── IntegrationTests/
│   └── UITests/
└── Package.swift
```

### Data Flow

```
View → ViewModel → Service → Repository/Cache → Model
  ↑                                        ↓
  └──── State update (Combine/async) ──────┘
```

- **Views** are thin and delegate user actions to view models
- **ViewModels** orchestrate business logic and expose `@Published` / `@Observable` state
- **Services** handle networking, persistence, and Git operations
- **Models** are value types (`struct`, `enum`) conforming to `Codable` and `Sendable`

---

## Testing Requirements

### Running Tests

```bash
# All tests
swift test

# Specific test target
swift test --filter GitPanelTests

# UI tests (via Xcode)
xcodebuild test -scheme GitPanel -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Coverage Expectations

- **New features**: 80%+ code coverage for the feature module
- **Bug fixes**: Include a regression test that fails before the fix and passes after
- **Critical paths**: Authentication, data persistence, and core Git operations require 90%+ coverage

### Test Organization

- Unit tests go in `Tests/UnitTests/` mirroring the source structure
- Integration tests go in `Tests/IntegrationTests/`
- UI tests go in `Tests/UITests/`
- Use descriptive test names: `test_fetchRepository_returnsDecodedModel_onSuccess`

---

## Pull Request Process

### Branch Naming

| Type | Pattern | Example |
|---|---|---|
| Feature | `feature/<short-description>` | `feature/diff-viewer-zoom` |
| Bug Fix | `fix/<short-description>` | `fix/crash-on-empty-repo` |
| Documentation | `docs/<short-description>` | `docs/update-api-reference` |
| Refactor | `refactor/<short-description>` | `refactor/extract-networking-layer` |

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Examples:**
```
feat(diff): add syntax highlighting for Swift files
fix(auth): handle expired tokens gracefully
docs(readme): update installation instructions
refactor(models): simplify RepositoryCodable conformance
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`

### Review Checklist

Before requesting a review, confirm:

- [ ] Code compiles without warnings
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] No force-unwraps (`!`) unless justified with a comment
- [ ] Public APIs have doc comments
- [ ] No hardcoded strings in UI (use localized strings)
- [ ] Changes are scoped — one logical change per PR
- [ ] PR description explains **what** and **why**

---

## Issue Guidelines

### Bug Reports

Use the **Bug Report** template and include:

1. **Environment**: macOS version, Xcode version, device/simulator
2. **Steps to Reproduce**: numbered, minimal steps
3. **Expected Behavior**: what should happen
4. **Actual Behavior**: what actually happens
5. **Screenshots/Logs**: if applicable
6. **Regression**: if this worked before, note the last working version

### Feature Requests

Use the **Feature Request** template and include:

1. **Problem**: the user problem you're trying to solve
2. **Proposed Solution**: your idea
3. **Alternatives Considered**: other approaches you thought about
4. **Additional Context**: mockups, references, or links

### Labels

| Label | Meaning |
|---|---|
| `good-first-issue` | Ideal for first-time contributors |
| `help-wanted` | Maintainers are looking for community help |
| `priority:high` | Will be addressed soon |
| `status:blocked` | Waiting on dependency or decision |

---

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold its standards of respectful and inclusive collaboration.

---

## License

By contributing to GitPanel, you agree that your contributions will be licensed under the same license as the project (see [LICENSE](LICENSE)).

All contributions are made under the same open-source terms. No CLA is required.

---

*Last updated: July 2026*
