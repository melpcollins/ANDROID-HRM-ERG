# Use Case 03: Start ERG Session

## Goal
Start a heart-rate-driven ERG workout session.

## Preconditions
- HRM and trainer are connected.
- User is on the main `Device Setup` screen.

## User Steps
1. In `ERG Control`, enter:
2. `Starting Watts`
3. `Target Heart Rate`
4. `Loop Interval (seconds)` (default: 10)
5. `Session Duration (HH:MM)`
6. Tap `Start`.

## Expected App Behavior
- Session enters running state.
- Input fields are hidden while running.
- Red `Stop` button appears on the same line as `ERG Control`.
- Initial trainer target power is set to the entered starting watts.
- A countdown timer starts from the entered session duration and decreases continuously.
- When remaining time is `<= 00:05:00`, the app enters `Cooldown` state automatically.
- In `Cooldown`, target heart rate is set to `95 bpm`.
- A clear on-screen cooldown indication is shown while cooldown is active.
