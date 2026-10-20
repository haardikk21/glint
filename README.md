# Glint

A native macOS command palette built with SwiftUI, AppKit, Carbon hotkeys, EventKit, and Spotlight. It runs as a menu bar app; press **Command–Space** to open it.

## Build and run

Requires macOS 14+ and Swift 5.10+ (Xcode Command Line Tools work). Run:

```sh
sh scripts/check.sh
sh scripts/bundle.sh
```

To also verify live exchange-rate providers, run `sh scripts/check-rates.sh` (requires network access).

The scripts prefer the installed macOS 26.5 SDK because this machine's default SDK references a SwiftUI plugin absent from Command Line Tools; on other machines they use the default SDK. The build script creates and opens `dist/Glint.app`. Move the app to `/Applications` for a stable location before enabling **Launch at login** in Settings. After changing the bundle location, reopen it and re-enable the login item if necessary.

## Features

- Search installed apps, including Finder, with fuzzy matching; open with Return. Results learn from the apps and commands you pick, with query-specific usage and recency stored locally. Shorter matches win initial ties, so `screen` puts Screenshot before Screen Sharing. On an empty search, Return does nothing until you select a result with the arrow keys or click it.
- Search **Accessibility**, **Privacy & Security**, **Storage**, **Displays**, **Mouse**, and many other System Settings panes to open them directly instead of navigating the Settings sidebar.
- **Search Files** is an explicit action in the launcher. Select it to search Spotlight-indexed files in your home directory (2+ characters). Generated folders such as `node_modules` and Rust `target` are excluded. Spotlight indexing must be enabled.
- Typed searches also offer **Search Google** in your browser, after matching results and before the explicit file-search action. Clipboard contents are never included in root search results.
- **Toggle Appearance** switches macOS between light and dark mode. **Pi** and **OpenCode** launch `pi` or `oc` in a new Ghostty tab when a window exists, otherwise in a new window. macOS may request Automation access to System Events or Ghostty the first time you use these commands. Ghostty's AppleScript setting must be enabled (it is enabled by default).
- Add bash commands in Settings; optionally record a modifier + key global shortcut. Commands execute from your home directory; script output is discarded.
- Allow macOS Calendar access in Settings (see below). An upcoming meeting with a Meet, Zoom, Teams, Webex, Whereby, Chime, or GoTo link appears from 2 minutes before its start until it ends (declined events are skipped; overlapping meetings each get a row). Press Return to join. If macOS drops Glint's Calendar permission, an "Allow Calendar Access" row appears in the launcher.
- Type `3m to s`, `1h30m to min`, `300m to km`, `5 in to cm`, `100 km/h to mph`, `2 l to ml`, `1 kg to lbs`, `5 GB to MB`, `32 F to C`, `0x1` (shows `1`), `0b101`, `255 to hex`, `0xff to binary`, or `base64 SGVsbG8=` for instant conversions; `to`, `in`, and `as` all work. `m` means minutes when the other unit is time and metres otherwise. Arithmetic supports `+ - * / % ^`, `1,000`-style numbers, and hex literals. `USD to CAD` assumes 1 USD; `5 USD to CAD`, `$20 to eur`, `234 ETH to USD`, and `1 ETH to BTC` use live Frankfurter / CoinGecko rates and require internet access.
- Do math directly in the search box: `1+2*3`, `10%3`, or `((1+2)*3)/6`. Supports `+`, `-`, `*`, `/`, `%` (remainder), decimals, unary signs, and nested parentheses; Return copies the result.
- Paste a transaction/block hash (`0x` plus 64 hex digits) or EVM address (`0x` plus 40 hex digits) to open it on BaseScan mainnet or Base Sepolia. A copied hash or address also appears as an action when the palette opens.
- Search **Clipboard History** to open its two-column browser (last 50 text copies, in memory only). Navigate with ↑/↓, Return to copy, Shift–Return to copy and paste into the previous app, or clear history there. Clipboard entries are searchable only inside this browser. Save snippets in Settings.
- Search **Snippets** and press Return to open the two-column browser: names on the left, selected content on the right. Use ↑/↓ to navigate, Return to copy, Shift–Return to copy and paste into the app you were using before Glint, and Escape to go back. **Manage Snippets** opens the Snippets editor. The first copy-and-paste requires macOS **System Settings → Privacy & Security → Accessibility** permission for Glint; without it, the snippet is still copied.
- Search **Emoji Picker** to browse an offline emoji grid (including country flags), with fuzzy searches over Unicode names and common keywords such as `happy`, `poop`, or `US flag`. Use arrow keys to navigate, Return to copy, Shift–Return to copy and paste into the previous app, or click an emoji to copy it.

If Command–Space is owned by Alfred or Spotlight, Glint shows a shortcut-unavailable message and automatically retries when it becomes free. Change the conflicting shortcut to use it here. Custom shortcuts report conflicts as well.

## Calendar access

Glint reads calendars already synced with the macOS Calendar app, including Google accounts. In Glint Settings, click **Allow Calendar Access** and grant macOS Calendar permission. Glint only reads events and checks for meeting links; it does not modify calendars. If permission was previously denied, enable Glint under **System Settings → Privacy & Security → Calendars**. No Google Cloud project or separate sign-in is needed.
