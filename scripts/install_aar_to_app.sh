#!/usr/bin/env bash
set -euo pipefail

# Build the SDK AAR, copy it to app/libs, and modify app/build.gradle to use the AAR

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK_MODULE_DIR="$ROOT_DIR/hev-socks5-sdk"
APP_DIR="$ROOT_DIR/app"
LIBS_DIR="$APP_DIR/libs"

echo "Building AAR for hev-socks5-sdk..."
"$ROOT_DIR/scripts/run_gradle.sh" ":hev-socks5-sdk:assembleRelease"

AAR_DIR="$SDK_MODULE_DIR/build/outputs/aar"
if [ ! -d "$AAR_DIR" ]; then
  echo "AAR output directory not found: $AAR_DIR" >&2
  exit 1
fi

# pick the release AAR (prefer files containing 'release')
AAR_FILE="$(ls -1 "$AAR_DIR"/*.aar 2>/dev/null | grep -i release | tail -n1 || true)"
if [ -z "$AAR_FILE" ]; then
  # fallback to any aar
  AAR_FILE="$(ls -1 "$AAR_DIR"/*.aar 2>/dev/null | tail -n1 || true)"
fi

if [ -z "$AAR_FILE" ]; then
  echo "No AAR found in $AAR_DIR" >&2
  exit 1
fi

echo "Found AAR: $AAR_FILE"

mkdir -p "$LIBS_DIR"
cp -v "$AAR_FILE" "$LIBS_DIR/"

AAR_BASENAME="$(basename "$AAR_FILE" .aar)"

APP_BUILD_FILE="$APP_DIR/build.gradle"
BACKUP="$APP_BUILD_FILE.bak"
cp -a "$APP_BUILD_FILE" "$BACKUP"

echo "Patching $APP_BUILD_FILE to use local AAR..."

# 1) Ensure repositories.flatDir { dirs 'libs' } exists; insert before first 'android {' if missing
if ! grep -q "flatDir.*libs" "$APP_BUILD_FILE"; then
  awk 'BEGIN{p="repositories { flatDir { dirs '\''libs'\'' } }"} /android[[:space:]]*\{/ && !done {print p; done=1} {print}' "$BACKUP" > "$APP_BUILD_FILE"
else
  cp -a "$BACKUP" "$APP_BUILD_FILE"
fi

# 2) Replace project dependency or insert implementation for the AAR
if grep -q "implementation project(':hev-socks5-sdk')" "$APP_BUILD_FILE"; then
  sed "s/implementation project(':hev-socks5-sdk')/implementation(name: '$AAR_BASENAME', ext: 'aar')/" "$APP_BUILD_FILE" > "$APP_BUILD_FILE.tmp" && mv "$APP_BUILD_FILE.tmp" "$APP_BUILD_FILE"
elif ! grep -q "implementation(name: '$AAR_BASENAME'" "$APP_BUILD_FILE"; then
  # insert into dependencies block after the opening line
  awk -v line="implementation(name: '$AAR_BASENAME', ext: 'aar')" 'BEGIN{inserted=0} /dependencies[[:space:]]*\{/ {print; getline; print; if(!inserted){print "    " line; inserted=1; next}} {print}' "$APP_BUILD_FILE" > "$APP_BUILD_FILE.tmp" && mv "$APP_BUILD_FILE.tmp" "$APP_BUILD_FILE"
fi

echo "AAR installed to $LIBS_DIR/$AAR_BASENAME. App build file patched (backup at $BACKUP)."
echo "You can now build or install the app: ./scripts/run_gradle.sh :app:installDebug"
