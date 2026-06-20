#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=version.env
source "$ROOT/scripts/version.env"
# shellcheck source=sources.env
source "$ROOT/scripts/sources.env"

APP_NAME="Moa-Lite"
APP="$ROOT/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
EXECUTABLE="$MACOS/$APP_NAME"
BUNDLE_ID="com.moarliu.moa-lite"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Moa-Lite Local Development Code Signing}"

check_mach_o_deployment_target() {
  local executable="$1"
  local minos
  minos="$(/usr/bin/otool -l "$executable" | awk '
    $1 == "cmd" && $2 == "LC_BUILD_VERSION" { in_build = 1; next }
    in_build && $1 == "minos" { print $2; exit }
    $1 == "cmd" && $2 == "LC_VERSION_MIN_MACOSX" { in_min = 1; next }
    in_min && $1 == "version" { print $2; exit }
  ')"

  if [[ -z "$minos" ]]; then
    echo "Missing Mach-O deployment target in $executable" >&2
    exit 1
  fi

  if [[ "$minos" != "$MACOS_DEPLOYMENT_TARGET" ]]; then
    echo "Mach-O deployment target mismatch in $executable: expected $MACOS_DEPLOYMENT_TARGET, got $minos" >&2
    exit 1
  fi
}

MOA_APP_ABS_SOURCES=()
for source in "${MOA_APP_SOURCES[@]}"; do
  MOA_APP_ABS_SOURCES+=("$ROOT/$source")
done

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

MACOSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" /usr/bin/swiftc \
  -target "$SWIFTC_TARGET" \
  -O \
  -framework ApplicationServices \
  -framework AppKit \
  -framework AVFoundation \
  -framework Combine \
  -framework CryptoKit \
  -framework Foundation \
  -framework ImageIO \
  -framework SwiftUI \
  -framework UniformTypeIdentifiers \
  "${MOA_APP_ABS_SOURCES[@]}" \
  -o "$EXECUTABLE"

chmod 755 "$EXECUTABLE"
check_mach_o_deployment_target "$EXECUTABLE"

if [[ -f "$ROOT/assets/moa-icon.icns" ]]; then
  /usr/bin/ditto --noextattr --noacl "$ROOT/assets/moa-icon.icns" "$RESOURCES/AppIcon.icns"
fi

if [[ -f "$ROOT/assets/moa-menubar-template.png" ]]; then
  /usr/bin/ditto --noextattr --noacl "$ROOT/assets/moa-menubar-template.png" "$RESOURCES/MoaMenuBarIcon.png"
fi

if [[ -d "$ROOT/assets/Localization" ]]; then
  while IFS= read -r -d '' lproj; do
    /usr/bin/ditto --noextattr --noacl "$lproj" "$RESOURCES/$(basename "$lproj")"
  done < <(find "$ROOT/assets/Localization" -maxdepth 1 -name "*.lproj" -type d -print0)
fi

find "$RESOURCES" -name ".DS_Store" -delete

cat >"$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MACOS_DEPLOYMENT_TARGET</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$CONTENTS/Info.plist"

if command -v codesign >/dev/null 2>&1; then
  if [[ "$CODE_SIGN_IDENTITY" != "-" ]] &&
     ! /usr/bin/security find-identity -v -p codesigning | grep -F "\"$CODE_SIGN_IDENTITY\"" >/dev/null; then
    echo "Missing code signing identity: $CODE_SIGN_IDENTITY" >&2
    echo "Run ./scripts/setup-local-code-signing.sh, or set CODE_SIGN_IDENTITY=- for ad-hoc signing." >&2
    exit 1
  fi

  if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
    /usr/bin/codesign --force --deep --timestamp=none --sign "$CODE_SIGN_IDENTITY" "$APP" >/dev/null
  else
    /usr/bin/codesign --force --deep --timestamp --options runtime --sign "$CODE_SIGN_IDENTITY" "$APP" >/dev/null
  fi
fi

echo "Built: $APP"
