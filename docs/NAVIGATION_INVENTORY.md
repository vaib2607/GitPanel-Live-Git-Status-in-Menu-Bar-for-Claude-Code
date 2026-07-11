# Navigation Inventory

This document tracks all visible interactive controls, their intended navigation logic, error states, and QA coverage. 
*Note: To be populated by Agent 1 (Navigation and Interaction).*

## Git Overview
| Control | Expected Action | Actual Route/Command | Error State |
|---------|-----------------|----------------------|-------------|
| Repository Selector | Open repository picker | - | - |
| Branch Chevron | Open branch list | `GitPanelRoute.branch(repoID)` | Error scoped to branch view |
| Changed Files Chevron | Open changed files | `GitPanelRoute.fileList(repoID)` | - |
| Stash Chevron | Open stash view | `GitPanelRoute.stash(repoID)` | - |
| Conflicts Chevron | Open conflict resolver | `GitPanelRoute.conflicts(repoID)` | - |
| Commit / Push Buttons | Execute Git commit/push | Command execution via `GitService` | Inline banner |

## Provider (Claude / Codex)
| Control | Expected Action | Actual Route/Command | Error State |
|---------|-----------------|----------------------|-------------|
| Plan Usage Chevron | Open usage detail | `GitPanelRoute.usageDetail(providerID)` | Fallback empty state |
| Cost Chevron | Open cost detail | `GitPanelRoute.costDetail(providerID)` | Fallback empty state |
| Usage Dashboard | Open global usage | `GitPanelRoute.usageDashboard(providerID)`| - |
| Status Page | Open web browser | `NSWorkspace.shared.open(...)` | Graceful failure |
