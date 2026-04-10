#!/bin/bash
# Build + codesign + (optional) launch MenuClock.app without Xcode.
# Usage:
#   ./build.sh          # build only
#   ./build.sh run      # build, kill any running instance, launch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SDK=$(xcrun --show-sdk-path)
APP="build/MenuClock.app"
BIN="build/MenuClock"

echo "→ Compiling Swift sources…"
swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macos13.0 \
  -parse-as-library \
  -O \
  -o "$BIN" \
  MenuClock/MenuClockApp.swift \
  MenuClock/AppDelegate.swift \
  MenuClock/Models/WorldClock.swift \
  MenuClock/Models/AppSettings.swift \
  MenuClock/Managers/SettingsManager.swift \
  MenuClock/Managers/ClockTicker.swift \
  MenuClock/Managers/CalendarManager.swift \
  MenuClock/Managers/CityDatabase.swift \
  MenuClock/Managers/WeatherManager.swift \
  MenuClock/Managers/TimeFormatting.swift \
  MenuClock/Managers/LaunchAtLoginManager.swift \
  MenuClock/ViewModels/MenuBarViewModel.swift \
  MenuClock/Views/MenuBarTitleView.swift \
  MenuClock/Views/DropdownView.swift \
  MenuClock/Views/WorldClockRow.swift \
  MenuClock/Views/EventRow.swift \
  MenuClock/Views/SettingsView.swift \
  MenuClock/Views/TimeZonePickerView.swift \
  MenuClock/Views/OnboardingView.swift \
  MenuClock/Views/AboutView.swift \
  MenuClock/Views/MeetingPlannerView.swift

echo "→ Assembling .app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MenuClock"

if [ ! -f build/AppIcon.icns ]; then
  echo "→ Generating app icon…"
  swift build/make_icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ -f MenuClock/Resources/cities.tsv ]; then
  cp MenuClock/Resources/cities.tsv "$APP/Contents/Resources/cities.tsv"
else
  echo "⚠️  MenuClock/Resources/cities.tsv missing — run build/fetch_cities.sh" >&2
fi

cp MenuClock/Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "MenuClock"        "$APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "com.menuclock.MenuClock" "$APP/Contents/Info.plist"
plutil -replace CFBundleName       -string "MenuClock"        "$APP/Contents/Info.plist"
# Insert or replace CFBundleIconFile
plutil -remove CFBundleIconFile "$APP/Contents/Info.plist" 2>/dev/null || true
plutil -insert  CFBundleIconFile -string "AppIcon" "$APP/Contents/Info.plist"

echo "→ Codesigning (ad-hoc)…"
codesign --force --deep --sign - \
  --entitlements MenuClock/MenuClock.entitlements \
  --options runtime \
  "$APP" >/dev/null
codesign --verify --verbose "$APP" 2>&1 | sed 's/^/   /'

echo "✓ Built $APP"

if [ "${1:-}" = "run" ]; then
  echo "→ Stopping previous instance (if any)…"
  pkill -f "build/MenuClock.app/Contents/MacOS/MenuClock" 2>/dev/null || true
  sleep 0.3
  echo "→ Launching…"
  open "$APP"
  sleep 0.5
  pgrep -lf "MenuClock.app" || echo "  (not running?)"
fi
