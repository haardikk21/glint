#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build
sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
if [ -d "$sdk" ]; then
    swiftc -sdk "$sdk" Sources/Glint/Conversions.swift Sources/Glint/MathExpression.swift \
        Sources/Glint/Fuzzy.swift \
        Sources/Glint/Models.swift Sources/Glint/Blockchain.swift Sources/Glint/ResultOrdering.swift \
        Sources/Glint/SearchUsage.swift Sources/Glint/SearchActions.swift \
        Sources/Glint/LauncherNavigation.swift Sources/Glint/SnippetSearch.swift Sources/Glint/EmojiCatalog.swift \
        Sources/Glint/MeetingLinks.swift Sources/Glint/SearchServices.swift \
        Sources/Glint/SystemActions.swift Sources/Glint/SystemSettingsCatalog.swift \
        Sources/Glint/GhosttyLauncher.swift \
        Tests/GlintChecks/main.swift -o .build/glint-check
else
    swiftc Sources/Glint/Conversions.swift Sources/Glint/MathExpression.swift \
        Sources/Glint/Fuzzy.swift \
        Sources/Glint/Models.swift Sources/Glint/Blockchain.swift Sources/Glint/ResultOrdering.swift \
        Sources/Glint/SearchUsage.swift Sources/Glint/SearchActions.swift \
        Sources/Glint/LauncherNavigation.swift Sources/Glint/SnippetSearch.swift Sources/Glint/EmojiCatalog.swift \
        Sources/Glint/MeetingLinks.swift Sources/Glint/SearchServices.swift \
        Sources/Glint/SystemActions.swift Sources/Glint/SystemSettingsCatalog.swift \
        Sources/Glint/GhosttyLauncher.swift \
        Tests/GlintChecks/main.swift -o .build/glint-check
fi
.build/glint-check
