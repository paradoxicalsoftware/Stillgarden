#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
MODE="${1:-native}"
APP="$ROOT/build/Stillgarden.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/* "$APP/Contents/Resources/"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
build_arch() {
    xcrun swiftc Sources/Stillgarden/main.swift -sdk "$SDK" -target "$1-apple-macosx13.0" -framework Cocoa -framework SwiftUI -framework AVFoundation -O -o "build/Stillgarden-$1"
}
if [ "$MODE" = "universal" ]; then
    build_arch arm64
    build_arch x86_64
    lipo -create build/Stillgarden-arm64 build/Stillgarden-x86_64 -output "$APP/Contents/MacOS/Stillgarden"
else
    build_arch "$(uname -m)"
    cp "build/Stillgarden-$(uname -m)" "$APP/Contents/MacOS/Stillgarden"
fi
codesign --force --deep --sign - "$APP"
echo "Built $APP"
