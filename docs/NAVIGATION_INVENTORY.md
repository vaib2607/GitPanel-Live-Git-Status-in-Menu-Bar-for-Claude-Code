# Navigation Inventory

This document tracks all visible interactive controls, their intended navigation logic, error states, and QA coverage. 
*Note: This is used by Agent 1 (Navigation and Interaction) and Agent 4 (Design System) to ensure every interaction has real logic and handles errors gracefully.*

## Top-Level Tabs (AppTab)
| Control | Expected Action | Current State | Error State |
|---------|-----------------|---------------|-------------|
| Overview Tab | Switch to `AppTab.overview` | Working | None |
| Codex Tab | Switch to `AppTab.codex` | Working | None |
| Claude Tab | Switch to `AppTab.claude` | Working | None |

## Overview - Main Dashboard (GitPanelRoute)
| Control | Expected Action | Actual Route/Command | Error State |
|---------|-----------------|----------------------|-------------|
| Repository Selector (`+` Button) | Open `NSOpenPanel` repo picker | `showRepoPicker = true` | No global toast; scoped alert if invalid |
| Repository Picker "Choose Repository" | Open `NSOpenPanel` repo picker | `showRepoPicker = true` | No global toast |
| Branch Chevron | Open branch list | `GitPanelRoute.branch(repoID)` | `branchesState = .failed` (scoped view) |
| Changed Files Chevron | Open changed files | `GitPanelRoute.fileList(repoID)` | Handled by `DataState` (TBD) |
| Stash Chevron | Open stash view | `GitPanelRoute.stash(repoID)` | Handled by `DataState` (TBD) |
| Conflicts Chevron | Open conflict resolver | `GitPanelRoute.conflicts(repoID)` | Handled by `DataState` (TBD) |
| Environment Menu Button | Open environment menu | `GitPanelRoute.environment` | None |
| Commit Button | Execute Git commit | Command execution via `GitService` | Scoped banner / Inline error |
| Push Button | Execute Git push | Command execution via `GitService` | Scoped banner / Inline error |

## Environment Menu
| Control | Expected Action | Actual Route/Command | Error State |
|---------|-----------------|----------------------|-------------|
| Repository Info | Open repo info | `GitPanelRoute.repositoryInfo(repoID)` | None |
| Multi-Agent Run | Open multi-agent | `GitPanelRoute.multiAgent` | None |
| Spending Dashboard | Open global spending | `GitPanelRoute.spending` | None |
| Build Dashboard | Open build dashboard | `GitPanelRoute.build` | None |
| Status Page | Open web browser | `NSWorkspace.shared.open(...)` | Graceful failure if URL invalid |
| MCP Settings | Open MCP settings | `GitPanelRoute.mcp` | None |
| Timeline View | Open timeline | `GitPanelRoute.timeline` | None |

## Provider Dashboards (Codex / Claude)
| Control | Expected Action | Actual Route/Command | Error State |
|---------|-----------------|----------------------|-------------|
| Plan Usage Chevron | Open usage detail | `GitPanelRoute.usageDetail(providerID)` | `DataState.failed` (Empty/Error state) |
| Cost Chevron | Open cost detail | `GitPanelRoute.costDetail(providerID)` | `DataState.failed` (Empty/Error state) |
| Usage Dashboard | Open global usage | `GitPanelRoute.usageDashboard(providerID)`| `DataState.failed` (Empty/Error state) |
| Status Page | Open web browser | `NSWorkspace.shared.open(...)` | Graceful failure |

## Global Back Navigation
| Control | Expected Action | Actual Route/Command | Error State |
|---------|-----------------|----------------------|-------------|
| Back Arrow (Header) | Return to previous route | `AppRouter.pop()` | Hidden on root route (`.main`) |

## To Do (Agent 1 & Agent 3)
1. **DataState Migration:** Update `GitPanelViewModel` to use `DataState` for status, log, and file lists to support proper empty/loading/error states instead of global toasts.
2. **Provider Logic:** Migrate hardcoded provider metrics to actual math or mocked persistent data, wrapped in `DataState` to prove `.loading` and `.failed` screens work.
3. **Error Banners:** Replace global `showBanner` usages for routine Git fetches (e.g. `128` errors) with scoped `DataState` failures.
