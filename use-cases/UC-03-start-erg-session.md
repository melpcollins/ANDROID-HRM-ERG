# Use Case 03: Start Workout Session

## Goal
Start either supported workout mode from one shared setup screen.

## Preconditions
- HRM and trainer are connected.
- User is on the main `Device Setup` screen.

## User Steps
1. Choose a workout mode:
2. `HR-ERG`
3. `Zone 2 Assessment`
4. Enter the setup values for the selected mode.
5. Tap `Start`.

## Expected App Behavior
- Session enters running state.
- `HR-ERG` asks for `Starting Watts`, `Target Heart Rate`, and `Session Duration`.
- `Zone 2 Assessment` asks for `Assessment Power` and uses a fixed 90-minute protocol.
- A countdown timer starts immediately and decreases only while the workout is not paused.
- A visible status label shows `Warm-up`, `Active` or `Assessment`, `Cooldown`, `Paused`, or `Completed`.
- A red `Stop` button is available while the workout is running.
