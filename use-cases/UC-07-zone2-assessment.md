# Use Case 07: Zone 2 Assessment Workout

## Goal
Run a fixed assessment ride that estimates a practical upper Zone 2 power from aerobic drift.

## User Steps
1. Choose `Zone 2 Assessment`.
2. Enter `Assessment Power`.
3. Tap `Start`.
4. Ride through the fixed 90-minute protocol.

## Protocol
- minutes `0-10`: trainer targets `80%` of assessment power
- minutes `10-85`: trainer targets `100%` of assessment power
- minutes `85-90`: trainer targets `60%` of assessment power

## Analysis Windows
- Early window: minutes `20-40`
- Late window: minutes `65-85`

## Expected Output
- `Power Fade (%)`
- `Aerobic Drift (%)`
- estimated Zone 2 power or range
- `Good` or `Limited` confidence
- one-line interpretation

## Recommendation Rules
- drift `< 3%`: suggest `assessmentPower` to `assessmentPower + 5W`
- drift `3-5%`: suggest `assessmentPower`
- drift `> 5%`: suggest `assessmentPower - 10W` to `assessmentPower - 5W`
