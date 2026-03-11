# Use Case 05: Live Session Metrics

## Goal
Give the rider a clear real-time view of session stability and control.

## Metrics Shown During Active Session
- `Heart Rate (avg 10s)`
- `Target HR`
- `Power`
- `Countdown (HH:MM:SS)`
- `Cooldown Status`
- `Drift (%)`

## Drift Definition
- `Drift (watts) = highest rolling 20-minute average power seen in this session - current rolling 20-minute average power`.
- `Drift (%) = Drift (watts) / current power * 100`.
- Display unit: percent (%).
- Rolling window for power average: 20 minutes.
- Drift is non-negative because the session peak rolling average only updates when a new high is reached.
- Example: `5 W` drift at `100 W` current power = `5%` drift.

## Drift Color Rules
- `<= 5%`: green
- `> 5% and <= 10%`: yellow
- `> 10%`: red
- If computed drift is `0`, display `--` instead of `0%`.

## Session Rules
- On session start, the tracked peak rolling average resets.
- Power sample history is retained for the full 20-minute window so rolling averages remain accurate.
- During the first 20 minutes of a session, the rolling average uses all available power samples so far.
- Countdown starts from the session duration configured at session start.
- When remaining time is `<= 00:05:00`, session enters cooldown.
- On cooldown entry, stop tracking drift, highest rolling 20-minute power, and current rolling 20-minute power (freeze final values from the moment cooldown begins).
- In cooldown, target heart rate is forced to `95 bpm` and cooldown status is shown.

## End of Session Summary
- At the end of the session, show:
  - `Your max 20 min power was X`
  - `Your ending rolling power was Y`
  - `Your drift was Z`
- If `Z > 5%`, also show:
  - `Warning: this was likely above zone 2 effort.`

## Expected App Behavior
- Metrics update continuously while session is running.
- Countdown is visible in live metrics and updates continuously.
- Cooldown status is visible in live metrics when active.
- Drift percentage updates continuously and color changes based on the threshold bands above.
- After cooldown starts, drift and rolling power values no longer change.
- End-of-session summary displays the frozen cooldown-entry values for `X`, `Y`, and `Z`.
