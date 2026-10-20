#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
if [ -d "$sdk" ]; then
    swift build -c release --sdk "$sdk"
else
    swift build -c release
fi
mkdir -p dist/Glint.app/Contents/MacOS
cp .build/release/Glint dist/Glint.app/Contents/MacOS/Glint
cp Info.plist dist/Glint.app/Contents/Info.plist
# Ad-hoc signatures change on every build. Pin the designated requirement to the bundle ID so
# macOS keeps privacy grants (Calendar, Automation) across rebuilds instead of silently dropping them.
codesign --force --sign - --identifier dev.haardik.glint \
    --requirements '=designated => identifier "dev.haardik.glint"' dist/Glint.app
open dist/Glint.app
