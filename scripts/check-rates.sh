#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build
sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
if [ -d "$sdk" ]; then
    swiftc -sdk "$sdk" -parse-as-library Sources/Glint/Conversions.swift \
        Tests/RateChecks/main.swift -o .build/glint-rate-check
else
    swiftc -parse-as-library Sources/Glint/Conversions.swift \
        Tests/RateChecks/main.swift -o .build/glint-rate-check
fi
.build/glint-rate-check
