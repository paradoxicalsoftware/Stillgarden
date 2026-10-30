#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
for scene in day night winter controls; do
    build/Stillgarden.app/Contents/MacOS/Stillgarden --render-demo "$scene" "$ROOT/docs/assets/$scene.png"
done
