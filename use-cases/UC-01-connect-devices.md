# Use Case 01: Connect Devices

## Goal
Connect the app to a Bluetooth heart-rate monitor (HRM) and a Bluetooth smart trainer (Wattbike).

## Preconditions
- Bluetooth is enabled on the phone.
- HRM and trainer are powered on and discoverable.
- App is installed and opened.

## User Steps
1. Open the `HRM` section.
2. Tap `Scan`.
3. Select and connect the HR monitor from the device list.
4. Open the `Wattbike Trainer` section.
5. Tap `Scan`.
6. Select and connect the trainer from the device list.

## Expected App Behavior
- Status pill is red while disconnected and green when connected.
- Connected section auto-collapses to a compact summary.
- Tapping the status pill toggles section expand/collapse.
- Selected device IDs are saved for future reconnect.
