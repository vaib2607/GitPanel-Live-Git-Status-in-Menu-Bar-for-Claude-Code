# GitPanel Roadmap — AI Developer Command Center

I want GitPanel to evolve from a simple Git status menu bar app into the ultimate native macOS command center for AI-assisted software development.

## Vision

GitPanel should provide developers with a single menu bar application that answers:

• What is my repository doing?
• What is my AI agent doing?
• What is my project status?
• Is anything broken?
• How much is AI costing me?
• What should I pay attention to right now?

The app should remain:
- Native macOS (SwiftUI/AppKit)
- Lightweight
- Extremely fast
- Low CPU/RAM usage
- Privacy-first (local-first whenever possible)
- Beautiful Apple-style UI
- Modular and extensible

It should support multiple AI coding agents instead of focusing on only one.

Supported agents:
- Claude Code
- OpenAI Codex CLI
- Gemini CLI
- Aider
- OpenCode
- Future providers via plugins

---

# Future Features

## AI Session Monitor

Automatically detect active AI coding sessions.

Display:
- Active agent
- Current model
- Session duration
- Running/Idle status
- Active workspace

Example:

Claude Code
Running • 42 min

or

Codex
Idle

---

## Token & Cost Tracking

Track usage per session.

Display:
- Input tokens
- Output tokens
- Total tokens
- Estimated cost
- Daily total
- Monthly total

Support:
- Claude
- OpenAI
- Gemini
- OpenRouter
- Local models where applicable

---

## Context Window Monitor

Display current context usage.

Example:

Context
████████░░

82%

Remaining:
36k tokens

Warn before context exhaustion.

---

## Multi-Agent Dashboard

Detect multiple agents running simultaneously.

Example

Claude      Running
Codex       Idle
Gemini      Running

Allow quick switching.

---

## Repository Dashboard

Display

Repository
Branch
Remote
Ahead/Behind
Modified files
Untracked files
Conflicts
Stash count

---

## Pull Request Status

Integrate GitHub.

Display

Open PR
Review requests
CI status
Merge conflicts
Latest comments

---

## Issue Tracker

Display assigned GitHub issues.

One click opens issue.

---

## Commit Assistant

Generate intelligent commit messages using AI.

Example

feat(auth): implement OAuth login flow

One-click commit.

---

## Diff Preview

Preview changed files directly inside GitPanel.

No terminal required.

---

## Build Monitor

Monitor

Swift build
npm
cargo
go
xcodebuild
gradle

Display

Running
Succeeded
Failed
Duration

---

## Test Dashboard

Display

Passing tests
Failing tests
Coverage
Latest run

---

## MCP Server Monitor

Monitor connected MCP servers.

Display

Filesystem
GitHub
Playwright
Supabase
Postgres
Linear

Show

Connected
Disconnected
Latency
Restart button

---

## AI Timeline

Create a timeline of AI work.

Example

10:15
Prompt submitted

↓

10:18
12 files modified

↓

10:20
Tests passed

↓

10:21
Commit created

↓

10:23
Push completed

---

## Workspace Overview

Display

Current repository
Language
LOC
Branch
AI provider
Current task
Project health

---

## Recent Projects

Quick switching between repositories.

---

## TODO Scanner

Display

TODO
FIXME
BUG
HACK
XXX

counts for the current repository.

---

## Git History Dashboard

Recent commits

Current branch

Recent merges

Reflog

Stashes

Tags

---

## Release Notes Generator

Automatically summarize changes since the previous release.

Example

Added
- AI Session Monitor
- Token Tracking

Improved
- Git polling

Fixed
- Branch detection

---

## Spending Dashboard

Daily AI costs

Weekly

Monthly

Per provider

Charts

---

## Plugin Architecture

Allow external plugins.

Possible plugins:

Docker

GitHub Actions

Supabase

Railway

Vercel

Netlify

Cloudflare

Firebase

Linear

Jira

Slack

Discord

---

## Notifications

Native macOS notifications.

Examples

Build failed

PR approved

Context nearly full

Large merge conflict

AI finished task

Tests passed

---

## Performance Goals

Cold launch under 500ms

Memory usage under 50MB

Minimal CPU while idle

Native animations only

No Electron

No web views unless absolutely necessary

---

## Architecture

Use a modular architecture.

Independent modules:

Git Engine

AI Engine

Provider Detection

Token Tracking

Notifications

GitHub Integration

Plugin Manager

UI Components

Settings

Logging

Each module should be independently testable.

---

# Long-Term Goal

GitPanel should become the definitive macOS menu bar companion for AI software engineers.

It should combine Git status, AI agent monitoring, token usage, repository health, build status, testing, GitHub integration, MCP monitoring, and developer productivity into a single elegant native application.

The experience should feel like an Apple-designed developer utility: instant, polished, reliable, and unobtrusive.
