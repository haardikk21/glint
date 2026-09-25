# Glint

A native macOS command palette built with SwiftUI, AppKit, Carbon hotkeys, Google Calendar, and Spotlight. It runs as a menu bar app; press **Option–Space** to open it.

## Build and run

Requires macOS 14+ and Swift 5.10+ (Xcode Command Line Tools work). Run:

```sh
sh scripts/check.sh
sh scripts/bundle.sh
```

To also verify live exchange-rate providers, run `sh scripts/check-rates.sh` (requires network access).

The scripts prefer the installed macOS 26.5 SDK because this machine's default SDK references a SwiftUI plugin absent from Command Line Tools; on other machines they use the default SDK. The build script creates and opens `dist/Glint.app`. Move the app to `/Applications` for a stable location before enabling **Launch at login** in Settings. After changing the bundle location, reopen it and re-enable the login item if necessary.

## Features

- Search installed apps with fuzzy matching; open with Return. On an empty search, Return does nothing until you select a result with the arrow keys or click it.
- Search Spotlight-indexed files in your home directory (2+ characters), omitting `node_modules`, Rust `target`, build artifacts, and other generated folders. Spotlight indexing must be enabled.
- Add bash commands in Settings; optionally record a modifier + key global shortcut. Commands execute from your home directory; script output is discarded.
- Connect directly to Google Calendar in Settings (see below). An upcoming meeting with a Meet, Zoom, Teams, Webex, Whereby, or Chime URL appears from 2 minutes before its start until it ends. Press Return to join.
- Type `5 GB to MB`, `32 F to C`, `0xFF`, `decimal 255`, or `base64 SGVsbG8=` for instant conversions. `5 USD to CAD` and `234 ETH to USD` use live Frankfurter / CoinGecko rates and require internet access.
- Paste a 66-character transaction or block hash (`0x` plus 64 hex digits) to open it as a transaction or block on BaseScan or Base Sepolia. A copied hash also appears as an action when the palette opens.
- Search clipboard history (last 50 text items, in memory only) or save snippets in Settings. Return copies the selected entry. Clear history from Settings or the palette.

If Option–Space or a custom shortcut is already owned by another app, Glint shows a shortcut-unavailable message. Change the other app's shortcut to use it here.

## Connect Google Calendar

1. In [Google Cloud Console](https://console.cloud.google.com/), create or select a project and enable **Google Calendar API**.
2. Configure the OAuth consent screen with the **Google Calendar read-only** scope (`https://www.googleapis.com/auth/calendar.readonly`). If the app is in testing mode, add your Google account as a test user.
3. Create an OAuth client of type **Desktop app** under **Google Auth Platform → Clients**. Copy its **client ID** (ending in `.apps.googleusercontent.com`). You do not need to paste a client secret.
4. In Glint Settings, paste that client ID and click **Connect Google Calendar**. The system browser opens Google's consent flow; the redirect goes to Glint's temporary `127.0.0.1` listener. Tokens are saved in macOS Keychain. **Disconnect** removes them locally.

The Calendar integration reads selected Google calendars through the Google Calendar API; it does not require macOS Calendar sync. Glint polls for meetings every 30 seconds while running. Google OAuth testing-mode grants may expire and require reconnecting.
