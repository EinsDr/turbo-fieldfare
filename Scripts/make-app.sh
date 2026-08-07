#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-/Applications/TurboFieldfare.app}"
BIN=".build/release"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/TurboFieldfareMac" "$BIN/TurboFieldfareDecodeService" "$APP/Contents/MacOS/"
for b in "$BIN"/*.bundle; do
  cp -R "$b" "$APP/Contents/Resources/"
  cp -R "$b" "$APP/Contents/MacOS/"
done
cp "$BIN"/*.dylib "$APP/Contents/MacOS/" 2>/dev/null || true

SRC="Sources/TurboFieldfareApp/Mac/Resources/turbofieldfare-app-icon.png"
SET="$(mktemp -d)/AppIcon.iconset"; mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$SRC" --out "$SET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$SRC" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>TurboFieldfare</string>
  <key>CFBundleExecutable</key><string>TurboFieldfareMac</string>
  <key>CFBundleIdentifier</key><string>com.drumih.turbofieldfare</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"
