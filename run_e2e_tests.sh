#!/bin/bash
# run_e2e_tests.sh - GitPanel E2E and Integration Test Suite Runner
# Compiles the package, configures clean mock environments, and executes the 4-tier test suite.

set -e

# Define root workspace path
WORKSPACE_ROOT="$(pwd)"

echo "--------------------------------------------------"
echo "⚙️  1. Compiling GitPanel package targets..."
echo "--------------------------------------------------"
swift build

echo ""
echo "--------------------------------------------------"
echo "📂 2. Setting up temporary mock environment..."
echo "--------------------------------------------------"
# Create a secure temporary home folder to prevent pollution of user's home files
TEMP_HOME=$(mktemp -d -t gitpanel-e2e-home-XXXXXX)
export HOME="$TEMP_HOME"

# Prepare dummy structure for SQLite and JSONL metrics
mkdir -p "$HOME/Library/Application Support/Cursor/User/globalStorage"
mkdir -p "$HOME/.claude/projects"

echo "Mock HOME directory initialized at: $HOME"

echo ""
echo "--------------------------------------------------"
echo "🧪 3. Executing Swift-based 4-Tier E2E Test Suite..."
echo "--------------------------------------------------"
swift test

echo ""
echo "--------------------------------------------------"
echo "🧹 4. Cleaning up temporary environment..."
echo "--------------------------------------------------"
rm -rf "$TEMP_HOME"

echo ""
echo "=================================================="
echo "🎉 SUCCESS: All GitPanel E2E and integration tests passed!"
echo "=================================================="
