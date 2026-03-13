# Use Case 04: Automatic Power Adjustment To Hold Target HR

## Goal
Keep rider heart rate near target (for example Zone 2) by adjusting trainer power automatically.

## Control Inputs Used
- Target HR from session start.
- Loop interval: 20 seconds.
- HR average window: 60 seconds.

## Core Logic
- Compute `delta = avgHR(60s) - targetHR`.
- Map delta to adjustment **rate** in **W/min**:
- `+1 => -3`, `+2 => -6`, `>=+3 => -10`
- `-1 => +3`, `-2 => +6`, `<=-3 => +10`
- Convert rate to per-loop adjustment using the 20-second loop:
  - `perLoopWatts = rateWPerMin * (loopSeconds / 60)`
  - Keep fractional carry between loops so that over 60 seconds the total
    adjustment equals `rateWPerMin` (before clamp).
- Apply clamp to safe power range (50 to 500 W).

## Worked Example (20 second loop)
- If `delta <= -3`, mapped rate is `+10 W/min`.
- At a 20-second loop, each tick applies about `+3.33 W` on average.
- Over 3 ticks (60 seconds), total increase is `+10 W` (not `+10 W` per loop).

## Expected App Behavior
- Power commands are sent repeatedly at the configured loop interval.
- If HR rises above target, trainer power is reduced.
- If HR drops below target, trainer power is increased.
- If HR becomes stale or either device disconnects, the workout enters `Paused` state.
- When fresh HR and both device connections return, automatic control resumes.
