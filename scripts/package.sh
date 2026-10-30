#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent build/Stillgarden.app "dist/Stillgarden-$VERSION-macOS-universal.zip"
(cd dist && shasum -a 256 "Stillgarden-$VERSION-macOS-universal.zip" > SHA256SUMS.txt)
echo "Release package created in dist/"
