#!/usr/bin/env bash
set -euo pipefail

# Build native libs using ndk-build (uses jni/Application.mk) and copy
# produced .so files into the library module's src/main/jniLibs/<abi>/

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
JNI_DIR="$ROOT_DIR/jni"
MODULE_DIR="$ROOT_DIR/hev-socks5-sdk"
NDK_BUILD=${NDK_BUILD:-ndk-build}

echo "Building native libs with ndk-build in $JNI_DIR..."
cd "$JNI_DIR"
$NDK_BUILD NDK_APPLICATION_MK=Application.mk

# Locate libs output (ndk-build may put into ../libs or ./libs)
if [ -d "$JNI_DIR/../libs" ]; then
  LIBS_PATH="$JNI_DIR/../libs"
elif [ -d "$JNI_DIR/libs" ]; then
  LIBS_PATH="$JNI_DIR/libs"
else
  LIBS_PATH="$(find "$JNI_DIR" -type d -name libs -print -quit || true)"
fi

if [ -z "$LIBS_PATH" ] || [ ! -d "$LIBS_PATH" ]; then
  echo "Could not find built libs directory. Looked in: $JNI_DIR/../libs and $JNI_DIR/libs"
  exit 1
fi

echo "Copying .so files from $LIBS_PATH to $MODULE_DIR/src/main/jniLibs/..."
mkdir -p "$MODULE_DIR/src/main/jniLibs"
for abi_dir in "$LIBS_PATH"/*; do
  abi_name=$(basename "$abi_dir")
  if [ -d "$abi_dir" ]; then
    mkdir -p "$MODULE_DIR/src/main/jniLibs/$abi_name"
    cp -v "$abi_dir"/libhev-socks5-tunnel.so "$MODULE_DIR/src/main/jniLibs/$abi_name/" || true
  fi
done

echo "Done. You can now run: ./gradlew :hev-socks5-sdk:assembleRelease"
