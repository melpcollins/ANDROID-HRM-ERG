# MVP Plan: Two Workout Modes and a Shared Session Engine

## Summary
- Refactor the app around one shared workout engine with two explicit modes: `HR-ERG` and `Zone 2 Assessment`.
- Build in this order: shared session/domain refactor, HR-ERG safety and durability, summary analytics, fixed-protocol assessment ride, then docs/tests polish.
- Keep BLE connect/reconnect and target-power trainer control as-is for MVP. Trainer-measured power and cadence stay out of scope.

## Key Changes
- Replace the ERG-only controller/state with a shared workout session controller and state model covering workout type, phase, pause reason, timers, live metrics, and summary output.
- Add workout configs for `HrErgConfig` and `Zone2AssessmentConfig`.
- Extract reusable helpers for HR averaging, power adjustment mapping, workout timing, analytics, and Zone 2 estimation.
- `HR-ERG` uses a 60-second HR average, 20-second control loop, cooldown at the last 5 minutes, in-ride target edits, and automatic pause/resume on stale HR or disconnect.
- `Zone 2 Assessment` uses one user-entered power plus a fixed 90-minute protocol:
  - `0-10 min`: `80%`
  - `10-85 min`: `100%`
  - `85-90 min`: `60%`
- Summary analytics use power fade and aerobic drift, with Zone 2 recommendation bands driven primarily by drift.

## Test Plan
- Unit test HR averaging, power-adjustment carry logic, pause/resume behavior, phase timing, analytics formulas, and Zone 2 estimate ranges.
- Widget test mode switching, per-mode setup forms, HR-ERG target edits, and the fixed 90-minute assessment countdown.
- Live validation should cover a stable HR-ERG ride, disconnect/reconnect recovery, and one full assessment ride that produces a recommendation without crashing.

## Assumptions
- Analytics are based on commanded power only.
- Durability is expressed through power fade, aerobic drift, and a short interpretation, not a separate score.
- The old live peak-rolling drift behavior is intentionally retired.
