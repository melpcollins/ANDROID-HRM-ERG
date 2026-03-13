# Use Case 05: Live Session Status And Summary Analytics

## Goal
Give the rider clear live control status and a reliable post-ride summary.

## Metrics Shown During Active Session
- `Heart Rate`
- `Heart Rate (avg 60s)`
- `Power`
- `Countdown (HH:MM:SS)`
- `Target HR` for `HR-ERG`
- `Last Adjustment` for `HR-ERG`
- `Workout Status`

## Session Rules
- Live metrics remain focused on control and state, not final analysis.
- Workouts pause when HR is stale or a device disconnects.
- `HR-ERG` enters cooldown automatically when `<= 00:05:00` remains and forces target HR to `95 bpm`.
- `Zone 2 Assessment` uses a fixed protocol:
  - minutes `0-10`: `80%` of assessment power
  - minutes `10-85`: `100%` of assessment power
  - minutes `85-90`: `60%` of assessment power

## Summary Analytics
- `HR-ERG` summary uses:
  - `Power Fade (%)`
  - `Aerobic Drift (%)`
  - short durability interpretation
- `Zone 2 Assessment` summary uses:
  - `Power Fade (%)`
  - `Aerobic Drift (%)`
  - estimated Zone 2 power or range
  - confidence label
  - short interpretation
- Analytics use the first and last available 20-minute windows from the analyzed portion of the ride.
- If there is not enough usable data, show a clear `analysis unavailable` message instead of a misleading number.

## Expected App Behavior
- Live metrics update while the workout is active or paused.
- Summary content appears during cooldown and remains visible after completion.
- Early-stop assessment rides show `Estimate unavailable because the assessment ended early.`
