# Use Case 04: Automatic Power Adjustment To Hold Target HR

## Goal
Keep rider heart rate near target (for example Zone 2) by adjusting trainer power automatically.

## Control Inputs Used
- Target HR from session start.
- Loop interval from session start.
- HR average window: 10 seconds.

## Core Logic
- Compute `delta = avgHR(10s) - targetHR`.
- Map delta to adjustment rate (W/min):
- `+1 => -3`, `+2 => -6`, `>=+3 => -10`
- `-1 => +3`, `-2 => +6`, `<=-3 => +10`
- Scale adjustment by selected loop interval.
- Apply clamp to safe power range (50 to 500 W).

## Expected App Behavior
- Power commands are sent repeatedly at the configured loop interval.
- If HR rises above target, trainer power is reduced.
- If HR drops below target, trainer power is increased.
