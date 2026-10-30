#!/bin/bash
# Optional authoring step, requires ffmpeg. Distributed builds use checked-in assets.
set -euo pipefail
cd "$(dirname "$0")/.."
ffmpeg -loglevel error -y -i Resources/garden.png -q:v 2 web/assets/garden.jpg
for audio in Resources/*.wav; do
  ffmpeg -loglevel error -y -i "$audio" -codec:a libmp3lame -q:a 4 "web/assets/$(basename "$audio" .wav).mp3"
done
