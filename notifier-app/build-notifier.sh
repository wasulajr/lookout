#!/usr/bin/env bash
# build-notifier.sh — Compile the Swift notifier binary and assemble the
# headsup-notifier.app bundle. Outputs to $DEST/headsup-notifier.app.
#
# Usage: ./build-notifier.sh <dest-dir>
#   e.g. ./build-notifier.sh ~/Library/Application\ Support/headsup
#
# Idempotent: rebuilds in place every time.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:?usage: build-notifier.sh <dest-dir>}"
APP="$DEST/headsup-notifier.app"

command -v swiftc >/dev/null 2>&1 || {
    echo "ERROR: swiftc not found. Install Xcode Command Line Tools: xcode-select --install" >&2
    exit 1
}

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Compile the Swift notifier. -O for optimization, link the two frameworks
# UNUserNotificationCenter needs.
swiftc -O \
    -framework Foundation \
    -framework UserNotifications \
    -o "$APP/Contents/MacOS/headsup-notifier" \
    "$SCRIPT_DIR/headsup-notifier.swift"

# Drop in Info.plist verbatim (no substitutions today, but the .template
# suffix leaves room for future setup-time variables).
cp "$SCRIPT_DIR/Info.plist.template" "$APP/Contents/Info.plist"

# Icon — built by build-icon.sh from a 1024×1024 source. If missing, the
# bundle still works but notifications show macOS's generic placeholder.
if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
    echo "WARN: $SCRIPT_DIR/AppIcon.icns missing — notifications will show the macOS generic icon." >&2
    echo "      Run ./build-icon.sh once a 1024×1024 source PNG is available." >&2
fi

# Ad-hoc codesign the bundle. Unsigned binaries on modern macOS get
# refused notification permission by UNUserNotificationCenter even when
# the bundle is otherwise valid. Ad-hoc signing gives the binary a
# stable cdhash identity that macOS uses to persist the user's
# Allow / Deny decision across runs. No Apple Developer cert required.
codesign --sign - --force --deep "$APP" 2>/dev/null || {
    echo "WARN: codesign failed — notifications may be silently denied on macOS 13+." >&2
}

# Register with Launch Services so macOS associates the bundle ID with
# this on-disk path (lets the system find the icon for notifications
# without the user having to Finder-open the .app first).
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
    -f "$APP" 2>/dev/null || true

echo "Built $APP"
