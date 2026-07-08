# Privacy Policy for GitPanel

**Last updated:** January 2026

## Overview

GitPanel is a macOS menu bar application that displays git repository status. This privacy policy explains what data GitPanel accesses and how it is used.

## Data Collection

**GitPanel does not collect, transmit, or store any data on external servers.**

All data processing happens locally on your Mac.

## Data Accessed Locally

GitPanel accesses the following data on your device:

### Git Repository Data
- Git status, branch names, diff statistics, and commit information
- Repository paths you select via the file picker
- Submodule and remote configuration from `.gitmodules` and `.git/config`
- All git operations are performed via the local `git` CLI — no data is sent over the network

### Claude Code Usage Data (Optional)
- Token counts and cost data parsed from local Claude Code JSONL logs at `~/.claude/projects/`
- This data never leaves your device
- This feature can be disabled in Settings

### Cursor Plan Tier (Optional)
- Best-effort detection of your Cursor subscription tier from local `state.vscdb` file
- Used only to display your usage remaining
- This data never leaves your device

## Network Usage

GitPanel makes **no outbound network connections**. All git operations are performed locally via the `git` command line tool. The GitHub CLI (`gh`) is invoked locally for PR status queries — GitPanel itself does not make any HTTP requests.

## Data Storage

GitPanel stores the following data in macOS `UserDefaults`:
- Your selected repository path
- Usage display preferences (enabled/disabled, manual value)

This data stays on your device and is not accessible to other applications.

## Third-Party Services

GitPanel does not integrate with any third-party analytics, advertising, or tracking services.

## Children's Privacy

GitPanel does not collect data from children under 13.

## Changes to This Policy

If this privacy policy changes, the updated version will be available at:
https://github.com/vaibhavkakar/GitPanel/blob/main/PRIVACY.md

## Contact

If you have questions about this privacy policy, please open an issue at:
https://github.com/vaibhavkakar/GitPanel/issues

## Open Source

GitPanel is open source under the MIT license. You can review the full source code at:
https://github.com/vaibhavkakar/GitPanel
