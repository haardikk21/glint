# Glint

A native macOS command palette built with SwiftUI, AppKit, Carbon hotkeys, EventKit, and Spotlight. It runs as a menu bar app; press **Option–Space** to open it.

## Build and run

Requires macOS 14+ and Swift 5.10+ (Xcode Command Line Tools work). Run:

```sh
sh scripts/check.sh
sh scripts/bundle.sh
```

To also verify live exchange-rate providers, run `sh scripts/check-rates.sh` (requires network access).

The scripts prefer the installed macOS 26.5 SDK because this machine's default SDK references a SwiftUI plugin absent from Command Line Tools; on other machines they use the default SDK. The build script creates and opens `dist/Glint.app`. Move the app to `/Applications` for a stable location before enabling **Launch at login** in Settings. After changing the bundle location, reopen it and re-enable the login item if necessary.

## Features

- Search installed apps, including Finder, with fuzzy matching; open with Return. On an empty search, Return does nothing until you select a result with the arrow keys or click it.
- **Search Files** is an explicit action in the launcher. Select it to search Spotlight-indexed files in your home directory (2+ characters). Generated folders such as `node_modules` and Rust `target` are excluded. Spotlight indexing must be enabled.
- **Toggle Appearance** switches macOS between light and dark mode. **Pi** and **OpenCode** launch `pi` or `oc` in a new Ghostty tab when a window exists, otherwise in a new window. macOS may request Automation access to System Events or Ghostty the first time you use these commands. Ghostty's AppleScript setting must be enabled (it is enabled by default).
- Add bash commands in Settings; optionally record a modifier + key global shortcut. Commands execute from your home directory; script output is discarded.
- Allow macOS Calendar access in Settings (see below). An upcoming meeting with a Meet, Zoom, Teams, Webex, Whereby, or Chime URL appears from 2 minutes before its start until it ends. Press Return to join.
- Type `5 GB to MB`, `32 F to C`, `0xFF` (shows `255`), `decimal 255`, or `base64 SGVsbG8=` for instant conversions. `USD to CAD` assumes 1 USD; `5 USD to CAD` and `234 ETH to USD` use live Frankfurter / CoinGecko rates and require internet access.
- Paste a transaction/block hash (`0x` plus 64 hex digits) or EVM address (`0x` plus 40 hex digits) to open it on BaseScan mainnet or Base Sepolia. A copied hash or address also appears as an action when the palette opens.
- Search clipboard history (last 50 text items, in memory only) or save snippets in Settings. Clear history from Settings or the palette.
- Search **Snippets** and press Return to open the two-column browser: names on the left, selected content on the right. Use ↑/↓ to navigate, Return to copy, Shift–Return to copy and paste into the app you were using before Glint, and Escape to go back. **Manage Snippets** opens the Snippets editor. The first copy-and-paste requires macOS **System Settings → Privacy & Security → Accessibility** permission for Glint; without it, the snippet is still copied.
- Search **Emoji Picker** to browse an offline emoji grid (including country flags), with fuzzy searches over Unicode names and common keywords such as `happy`, `poop`, or `US flag`. Use arrow keys to navigate, Return to copy, Shift–Return to copy and paste into the previous app, or click an emoji to copy it.

If Option–Space or a custom shortcut is already owned by another app, Glint shows a shortcut-unavailable message. Change the other app's shortcut to use it here.

## Calendar access

Glint reads calendars already synced with the macOS Calendar app, including Google accounts. In Glint Settings, click **Allow Calendar Access** and grant macOS Calendar permission. Glint only reads events and checks for meeting links; it does not modify calendars. If permission was previously denied, enable Glint under **System Settings → Privacy & Security → Calendars**. No Google Cloud project or separate sign-in is needed.
