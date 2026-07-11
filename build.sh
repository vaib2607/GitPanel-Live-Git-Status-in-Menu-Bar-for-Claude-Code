#!/bin/bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
APP_NAME="GitPanel"
BUNDLE="${APP_NAME}.app"
BUILD_DIR=".build/release"
RESOURCES="Resources"
INFO_PLIST="${RESOURCES}/Info.plist"
ENTITLEMENTS="${RESOURCES}/${APP_NAME}.entitlements"
DMG_NAME="${APP_NAME}"
DMG_VOLUME_NAME="${APP_NAME}"
BUILD_PATH=""

# ─── Defaults ────────────────────────────────────────────────────────────────
DO_DMG=false
DO_NOTARIZE=false
IS_RELEASE=false

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Helpers ─────────────────────────────────────────────────────────────────
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

cleanup() {
    if [[ -n "${DMG_TEMP_DIR:-}" && -d "$DMG_TEMP_DIR" ]]; then
        rm -rf "$DMG_TEMP_DIR"
    fi
}
trap cleanup EXIT

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --dmg         Create a DMG disk image after building
  --notarize    Notarize and staple the app (implies --dmg and --release)
  --release     Use Developer ID signing (required for notarization)
  -h, --help    Show this help message

Examples:
  ./build.sh                      # Quick local build
  ./build.sh --dmg                # Build and package as DMG
  ./build.sh --release --dmg      # Release build with DMG
  ./build.sh --notarize           # Full release: build, DMG, notarize, staple

Environment variables (for --notarize):
  APPLE_ID             Your Apple ID email
  APPLE_TEAM_ID        Your 10-character Apple Developer Team ID
  APP_PASSWORD         App-specific password (not your Apple ID password)
  KEYCHAIN_PROFILE     Keychain profile name (default: notarytool-profile)
EOF
    exit 0
}

# ─── Parse Arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dmg)        DO_DMG=true;      shift ;;
        --notarize)   DO_NOTARIZE=true; shift ;;
        --release)    IS_RELEASE=true;  shift ;;
        -h|--help)    usage ;;
        *)            fail "Unknown option: $1 (use --help for usage)" ;;
    esac
done

# --notarize implies --release and --dmg
if $DO_NOTARIZE; then
    DO_DMG=true
    IS_RELEASE=true
fi

# ─── Read Version from Info.plist ────────────────────────────────────────────
read_plist_value() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print ${key}" "$INFO_PLIST" 2>/dev/null || fail "Cannot read ${key} from ${INFO_PLIST}"
}

VERSION=$(read_plist_value "CFBundleShortVersionString")
BUILD_NUMBER=$(read_plist_value "CFBundleVersion")
BUNDLE_ID=$(read_plist_value "CFBundleIdentifier")

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           GitPanel Build Script                 ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
info "App:        ${APP_NAME} v${VERSION} (build ${BUILD_NUMBER})"
info "Bundle ID:  ${BUNDLE_ID}"
info "Mode:       $(if $IS_RELEASE; then echo 'Release (Developer ID)'; else echo 'Local (ad-hoc)'; fi)"
info "DMG:        $(if $DO_DMG; then echo 'Yes'; else echo 'No'; fi)"
info "Notarize:   $(if $DO_NOTARIZE; then echo 'Yes'; else echo 'No'; fi)"
echo ""

# ─── Step 1: Clean Previous Build ───────────────────────────────────────────
info "Cleaning previous build artifacts..."
rm -rf "$BUNDLE"
rm -f "${DMG_NAME}.dmg"
ok "Clean"

# ─── Step 2: Swift Build ────────────────────────────────────────────────────
info "Building with swift build -c release..."
BUILD_PATH=$(swift build -c release --show-bin-path 2>&1) || fail "swift build failed"
EXECUTABLE="${BUILD_PATH}/${APP_NAME}"

if [[ ! -f "$EXECUTABLE" ]]; then
    fail "Executable not found at ${EXECUTABLE}"
fi

ok "Build succeeded"

# ─── Step 3: Create .app Bundle ─────────────────────────────────────────────
info "Creating ${BUNDLE}..."

mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"
mkdir -p "${BUNDLE}/Contents/Frameworks"

# Copy executable
cp "$EXECUTABLE" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "$INFO_PLIST" "${BUNDLE}/Contents/Info.plist"

# Copy resources
cp "$ENTITLEMENTS" "${BUNDLE}/Contents/Resources/${APP_NAME}.entitlements" 2>/dev/null || \
    warn "Entitlements file not found, skipping"

cp "${RESOURCES}/model_prices.json" "${BUNDLE}/Contents/Resources/model_prices.json" 2>/dev/null || \
    warn "model_prices.json not found, skipping"

cp "${RESOURCES}/GitPanel.icns" "${BUNDLE}/Contents/Resources/GitPanel.icns" 2>/dev/null || \
    warn "App icon not found, skipping"

# Copy Assets.xcassets if it exists
if [[ -d "${RESOURCES}/Assets.xcassets" ]]; then
    cp -R "${RESOURCES}/Assets.xcassets" "${BUNDLE}/Contents/Resources/Assets.xcassets"
fi

ok "Bundle created"

# ─── Step 4: Code Signing ───────────────────────────────────────────────────
info "Code signing..."

if $IS_RELEASE; then
    # Release: use Developer ID Application
    SIGNING_ID="Developer ID Application"
    if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
        warn "APPLE_TEAM_ID not set, falling back to first available Developer ID identity"
        SIGNING_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
        if [[ -z "$SIGNING_ID" ]]; then
            fail "No Developer ID Application identity found in keychain"
        fi
    else
        SIGNING_ID="Developer ID Application (${APPLE_TEAM_ID})"
    fi

    codesign --force --deep --sign "$SIGNING_ID" \
        --options runtime \
        --timestamp \
        --entitlements "$ENTITLEMENTS" \
        "$BUNDLE" || fail "Code signing failed"
else
    # Local: ad-hoc sign
    codesign --force --deep --sign - \
        --entitlements "$ENTITLEMENTS" \
        "$BUNDLE" 2>/dev/null || \
    codesign --force --deep --sign - "$BUNDLE"
fi

# Verify signature
codesign --verify --verbose=2 "$BUNDLE" 2>&1 | head -5 || warn "Signature verification had warnings"

# Remove quarantine
xattr -d com.apple.quarantine "$BUNDLE" 2>/dev/null || true

ok "Code signed"

# ─── Step 5: Create DMG ────────────────────────────────────────────────────
if $DO_DMG; then
    info "Creating DMG..."

    DMG_TEMP_DIR=$(mktemp -d -t gitpanel-dmg)

    # Copy .app to temp directory
    cp -R "$BUNDLE" "${DMG_TEMP_DIR}/${BUNDLE}"

    # Create symlink to /Applications
    ln -s /Applications "${DMG_TEMP_DIR}/Applications"

    # Check for custom background image
    BACKGROUND=""
    if [[ -f "${RESOURCES}/dmg-background.png" ]]; then
        BACKGROUND="${RESOURCES}/dmg-background.png"
        info "Using custom DMG background"
    elif [[ -f "${RESOURCES}/dmg-background@2x.png" ]]; then
        BACKGROUND="${RESOURCES}/dmg-background@2x.png"
        info "Using custom DMG background (Retina)"
    fi

    # Determine window size arguments
    WINDOW_SIZE=""
    if [[ -n "$BACKGROUND" ]]; then
        # Default window size for background image
        WINDOW_SIZE="-window size 660,400"
    else
        WINDOW_SIZE="-window size 500,300"
    fi

    # Create DMG
    DMG_FILE="${DMG_NAME}-${VERSION}.dmg"
    rm -f "$DMG_FILE"

    hdiutil create \
        -volname "$DMG_VOLUME_NAME" \
        -srcfolder "$DMG_TEMP_DIR" \
        -ov \
        -format UDZO \
        -imagekey zlib-level=9 \
        ${BACKGROUND:+-background "$BACKGROUND"} \
        $WINDOW_SIZE \
        "$DMG_FILE" || fail "hdiutil create failed"

    # Clean up temp directory
    rm -rf "$DMG_TEMP_DIR"
    DMG_TEMP_DIR=""

    ok "DMG created: ${DMG_FILE}"
fi

# ─── Step 6: Notarize ──────────────────────────────────────────────────────
if $DO_NOTARIZE; then
    info "Submitting for notarization..."

    # Validate required environment variables
    : "${APPLE_ID:?Set APPLE_ID environment variable}"
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID environment variable}"
    : "${APP_PASSWORD:?Set APP_PASSWORD environment variable (app-specific password)}"

    KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-notarytool-profile}"

    # Check if keychain profile exists
    if ! xcrun notarytool info "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
        info "Creating keychain profile '${KEYCHAIN_PROFILE}'..."
        xcrun notarytool store-credentials "$KEYCHAIN_PROFILE" \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$APP_PASSWORD" || fail "Failed to store notarization credentials"
    fi

    # Submit the DMG for notarization
    xcrun notarytool submit "$DMG_FILE" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        --wait \
        --timeout 30m || fail "Notarization submission failed"

    # Staple the notarization ticket to the DMG
    info "Stapling notarization ticket..."
    xcrun stapler staple "$DMG_FILE" || fail "Stapling failed"

    ok "Notarization complete"

    # Also staple the .app bundle (useful if distributing the .app directly)
    info "Stapling ticket to ${BUNDLE}..."
    xcrun stapler staple "$BUNDLE" 2>/dev/null || warn "Could not staple .app (non-critical)"

    # Verify notarization
    spctl --assess --type open --context context:primary-signature "$DMG_FILE" 2>&1 && \
        ok "Notarization verified" || warn "spctl check had warnings"
fi

# ─── Step 7: Generate Checksums ─────────────────────────────────────────────
info "Generating checksums..."

CHECKSUM_FILE="checksums.txt"
> "$CHECKSUM_FILE"

if [[ -f "${DMG_FILE:-}" ]]; then
    shasum -a 256 "$DMG_FILE" >> "$CHECKSUM_FILE"
    ok "DMG checksum: $(cut -d' ' -f1 "$CHECKSUM_FILE")"
fi

shasum -a 256 "$BUNDLE" 2>/dev/null >> "$CHECKSUM_FILE" || \
    warn "Could not checksum bundle directory"

ok "Checksums written to ${CHECKSUM_FILE}"

# ─── Step 8: Summary ────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                 Build Summary                   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  App:           ${GREEN}${BUNDLE}${NC}"
echo -e "  Version:       ${GREEN}${VERSION}${NC} (build ${BUILD_NUMBER})"
echo -e "  Signing:       ${GREEN}$(if $IS_RELEASE; then echo 'Developer ID'; else echo 'Ad-hoc'; fi)${NC}"

if $DO_DMG && [[ -f "${DMG_FILE:-}" ]]; then
    DMG_SIZE=$(du -h "$DMG_FILE" | cut -f1)
    echo -e "  DMG:           ${GREEN}${DMG_FILE}${NC} (${DMG_SIZE})"
fi

if $DO_NOTARIZE; then
    echo -e "  Notarized:     ${GREEN}Yes${NC}"
    echo -e "  Stapled:       ${GREEN}Yes${NC}"
fi

echo -e "  Checksums:     ${GREEN}${CHECKSUM_FILE}${NC}"
echo ""

if ! $DO_DMG && ! $DO_NOTARIZE; then
    echo -e "  Run with:  ${GREEN}open ${BUNDLE}${NC}"
fi

if $DO_DMG && ! $DO_NOTARIZE; then
    echo -e "  Install:   ${GREEN}open ${DMG_FILE:-${DMG_NAME}-${VERSION}.dmg}${NC} and drag to Applications"
fi

if $DO_NOTARIZE; then
    echo -e "  Ready for distribution: ${GREEN}${DMG_FILE:-${DMG_NAME}-${VERSION}.dmg}${NC}"
fi

echo ""
ok "Build complete!"
