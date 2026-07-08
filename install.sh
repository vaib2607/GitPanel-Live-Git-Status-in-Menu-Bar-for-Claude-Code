#!/bin/bash
set -e

REPO="https://github.com/vaib2607/GitPanel-Live-Git-Status-in-Menu-Bar-for-Claude-Code.git"
INSTALL_DIR="$HOME/Applications/GitPanel"
APP_NAME="GitPanel.app"

echo "=== GitPanel Installer ==="
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: GitPanel requires macOS"
    exit 1
fi

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1)
if [[ "$MACOS_VERSION" -lt 13 ]]; then
    echo "Error: GitPanel requires macOS 13.0 or later"
    exit 1
fi

# Check git
if ! command -v git &> /dev/null; then
    echo "Error: git is required but not installed"
    exit 1
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Clone or update
if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Updating GitPanel..."
    cd "$INSTALL_DIR"
    git pull
else
    echo "Cloning GitPanel..."
    git clone "$REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Build
echo ""
echo "Building GitPanel..."
bash build.sh

# Move to Applications
echo ""
echo "Installing to /Applications..."
rm -rf "/Applications/$APP_NAME"
cp -R "GitPanel.app" "/Applications/$APP_NAME"

echo ""
echo "=== Done! ==="
echo ""
echo "GitPanel has been installed to /Applications/$APP_NAME"
echo ""
echo "To run:"
echo "  open /Applications/$APP_NAME"
echo ""
echo "To add to Login Items (optional):"
echo "  System Settings → General → Login Items → Add GitPanel"
