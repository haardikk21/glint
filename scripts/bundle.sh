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
codesign --force --sign - dist/Glint.app
open dist/Glint.app
