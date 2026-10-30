#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p work
build/Stillgarden.app/Contents/MacOS/Stillgarden --self-test
python3 scripts/check_assets.py
