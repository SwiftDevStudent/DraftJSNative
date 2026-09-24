#!/bin/zsh
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ROOT="${DRAFTJS_PREVIEW_APP_PATH:-/private/tmp/DraftJSNativePreview.app}"
SCRATCH_PATH="${SWIFT_SCRATCH_PATH:-/private/tmp/draftjsnative-build}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/draftjsnative-clang-cache}"

cd "$PACKAGE_ROOT"
swift build --disable-sandbox --scratch-path "$SCRATCH_PATH" --product draftjs-native-preview
BIN_PATH="$(swift build --disable-sandbox --scratch-path "$SCRATCH_PATH" --show-bin-path)"

mkdir -p "$APP_ROOT/Contents/MacOS" "$APP_ROOT/Contents/Resources"
cp -f "$BIN_PATH/draftjs-native-preview" "$APP_ROOT/Contents/MacOS/"
cp -X -f "$PACKAGE_ROOT/Examples/sample-article-envelope.json" "$APP_ROOT/Contents/Resources/"
cat > "$APP_ROOT/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>draftjs-native-preview</string>
  <key>CFBundleIdentifier</key><string>org.draftjsnative.preview</string>
  <key>CFBundleName</key><string>DraftJSNativePreview</string>
  <key>CFBundleDisplayName</key><string>DraftJSNative Preview</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xattr -rc "$APP_ROOT"
codesign --force --sign - "$APP_ROOT"
print -- "$APP_ROOT"
