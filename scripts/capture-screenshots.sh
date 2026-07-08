#!/bin/bash
# Capture screenshots of GitPanel for App Store
# Usage: bash scripts/capture-screenshots.sh

set -e

APP_NAME="GitPanel"
SCREENSHOT_DIR="screenshots"
TIMESTAMP=$(date +%Y%m%d)

echo "=== GitPanel Screenshot Capture ==="
echo ""

# Step 1: Ensure app is running
echo "1. Ensuring $APP_NAME is running..."
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1
open GitPanel.app
sleep 2

# Step 2: Check if app is running
if ! pgrep -x "$APP_NAME" > /dev/null; then
    echo "   ERROR: $APP_NAME failed to launch"
    exit 1
fi
echo "   $APP_NAME is running"

# Step 3: Click the status bar item to show the popover
echo "2. Opening popover..."
osascript -e '
tell application "System Events"
    tell process "GitPanel"
        -- Click the status bar item
        set statusItems to every status bar item of menu bar 1
        repeat with item in statusItems
            try
                click item
                delay 0.5
            end try
        end repeat
    end tell
end tell
' 2>/dev/null || echo "   Note: Accessibility permission may be needed for auto-click"

sleep 1

# Step 4: Capture screenshots
echo "3. Capturing screenshots..."
echo ""
echo "   The popover should be visible now."
echo "   Taking screenshot in 3 seconds..."
echo "   (Click elsewhere to dismiss after each shot)"
echo ""

# Screenshot 1: Full panel (main view)
echo "   [1/4] Main panel view..."
screencapture -x -r "$SCREENSHOT_DIR/${TIMESTAMP}_main_panel.png"
echo "   Saved: $SCREENSHOT_DIR/${TIMESTAMP}_main_panel.png"
sleep 1

# Step 5: Open branch list
echo "   [2/4] Branch list..."
osascript -e '
tell application "System Events"
    tell process "GitPanel"
        set statusItems to every status bar item of menu bar 1
        repeat with item in statusItems
            try
                click item
                delay 0.5
            end try
        end repeat
    end tell
end tell
' 2>/dev/null || true
sleep 1

screencapture -x -r "$SCREENSHOT_DIR/${TIMESTAMP}_branch_list.png"
echo "   Saved: $SCREENSHOT_DIR/${TIMESTAMP}_branch_list.png"
sleep 1

# Step 6: Dismiss and reopen for commit view
echo "   [3/4] Commit view..."
osascript -e 'tell application "System Events" to key code 53' 2>/dev/null || true
sleep 0.5
osascript -e '
tell application "System Events"
    tell process "GitPanel"
        set statusItems to every status bar item of menu bar 1
        repeat with item in statusItems
            try
                click item
                delay 0.5
            end try
        end repeat
    end tell
end tell
' 2>/dev/null || true
sleep 1

screencapture -x -r "$SCREENSHOT_DIR/${TIMESTAMP}_commit_view.png"
echo "   Saved: $SCREENSHOT_DIR/${TIMESTAMP}_commit_view.png"

# Step 7: Menu bar icon (without popover)
echo "   [4/4] Menu bar icon..."
osascript -e 'tell application "System Events" to key code 53' 2>/dev/null || true
sleep 0.5

# Get the status item position and capture just the menu bar
screencapture -x -r -l $(osascript -e 'tell application "System Events" to tell process "GitPanel" to id of window 1' 2>/dev/null || echo "0") "$SCREENSHOT_DIR/${TIMESTAMP}_menu_bar.png" 2>/dev/null || \
screencapture -x -r "$SCREENSHOT_DIR/${TIMESTAMP}_menu_bar.png"
echo "   Saved: $SCREENSHOT_DIR/${TIMESTAMP}_menu_bar.png"

echo ""
echo "=== Done! ==="
echo ""
echo "Screenshots saved to: $SCREENSHOT_DIR/"
ls -la "$SCREENSHOT_DIR/"*.png 2>/dev/null || echo "   (check screenshots/ directory)"
echo ""
echo "NOTE: These are raw captures. For App Store, you may want to:"
echo "  1. Crop to 2560x1600 (16:10) using Preview or sips"
echo "  2. Add device frames if needed"
echo "  3. Add captions/overlays for feature highlights"
