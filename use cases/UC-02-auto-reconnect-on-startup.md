# Use Case 02: Auto Reconnect On Startup

## Goal
Reconnect to previously saved HRM and trainer devices automatically when the app launches.

## Preconditions
- User has connected both devices at least once before.
- Saved device IDs exist in app storage.

## User Steps
1. Close the app.
2. Reopen the app with both devices available.

## Expected App Behavior
- App attempts reconnect for HRM and trainer automatically.
- Each device reconnect sequence retries up to 3 times.
- If reconnect still fails, manual `Reconnect saved` remains available.
- `Reconnect saved` uses the same high-emphasis style as `Start`.
