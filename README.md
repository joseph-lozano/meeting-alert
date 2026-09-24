# Meeting Alert

A small macOS menu bar app that shows a full-screen alert right before your meetings. It's a homemade replacement for "In Your Face".

## Setup

1. Add your Google account in **System Settings › Internet Accounts** and turn on Calendars.
2. Build and install:
   ```sh
   ./scripts/build-app.sh --install
   open "/Applications/Meeting Alert.app"
   ```
3. Grant calendar access when prompted. Then open **Settings…** from the bell icon, pick your calendar and turn on **Launch at login**.

## Features

- Full-screen alert 1 minute before each meeting (you can change the lead time), shown on every display.
- **Join** button for Zoom, Google Meet, Teams, Webex and other video links. Press Return to join and Esc to dismiss.
- Snooze options: remind me at start time, in 1 minute, or in 5 minutes.
- Filters: working hours and days, skip all-day, declined, or solo events, and exclude meetings by title (plain text or regex).
- The **Upcoming** tab in Settings lists the next 24 hours and shows which events will alert and why the others are skipped.
- You can pause alerts from the menu bar.

## Development

```sh
swift test                                   # filter and link-detection tests
./scripts/build-app.sh                       # build/Meeting Alert.app
open "build/Meeting Alert.app" --args --test-alert   # launch and show a test alert
```

Calendar access (EventKit) only works from the `.app` bundle, not from `swift run`.
