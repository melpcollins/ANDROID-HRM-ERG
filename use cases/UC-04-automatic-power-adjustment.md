# Use Case 04: Automatic Power Adjustment To Hold Target HR

## Goal
Keep rider heart rate near target (for example Zone 2) by adjusting trainer power automatically.

## Control Inputs Used
- Target HR from session start.
- Loop interval from session start.
- HR average window: 10 seconds.

## Core Logic
- Compute `delta = avgHR(10s) - targetHR`.
- Map delta to adjustment **rate** in **W/min**:
- `+1 => -3`, `+2 => -6`, `>=+3 => -10`
- `-1 => +3`, `-2 => +6`, `<=-3 => +10`
- Convert rate to per-loop adjustment using the selected loop interval:
  - `perLoopWatts = rateWPerMin * (loopSeconds / 60)`
  - Keep fractional carry between loops so that over 60 seconds the total
    adjustment equals `rateWPerMin` (before clamp).
- Apply clamp to safe power range (50 to 500 W).

## Worked Example (10 second loop)
- If `delta <= -3`, mapped rate is `+10 W/min`.
- At a 10 second loop, each tick applies about `+1.67 W` on average.
- Over 6 ticks (60 seconds), total increase is `+10 W` (not `+10 W` per loop).

## Expected App Behavior
- Power commands are sent repeatedly at the configured loop interval.
- If HR rises above target, trainer power is reduced.
- If HR drops below target, trainer power is increased.
