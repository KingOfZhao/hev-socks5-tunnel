#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER_DIR="$ROOT_DIR/.gradle-wrapper"
GRADLE_VERSION="7.6"

if [ $# -eq 0 ]; then
  echo "Usage: $0 <gradle-args>"
  echo "Example: $0 :app:installDebug"
  exit 1
fi

cd "$ROOT_DIR"

if [ -x "$ROOT_DIR/gradlew" ]; then
  exec "$ROOT_DIR/gradlew" "$@"
fi

if command -v gradle >/dev/null 2>&1; then
  exec gradle "$@"
fi

mkdir -p "$WRAPPER_DIR"
DIST_DIR="$WRAPPER_DIR/gradle-$GRADLE_VERSION"

if [ ! -d "$DIST_DIR" ]; then
  echo "Downloading Gradle $GRADLE_VERSION..."
  ZIP="$WRAPPER_DIR/gradle-$GRADLE_VERSION-bin.zip"
  URL="https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip"
  if command -v curl >/dev/null 2>&1; then
    curl -L -o "$ZIP" "$URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$ZIP" "$URL"
  else
    echo "curl or wget required to download Gradle. Install one or provide a gradle binary in PATH." >&2
    exit 1
  fi
  echo "Extracting..."
  unzip -q "$ZIP" -d "$WRAPPER_DIR"
  rm -f "$ZIP"
fi

GRADLE_BIN="$DIST_DIR/bin/gradle"
if [ ! -x "$GRADLE_BIN" ]; then
  chmod +x "$GRADLE_BIN" || true
fi

exec "$GRADLE_BIN" "$@"
