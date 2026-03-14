# Bluetooth Pre-Launch QA Plan

This checklist is the manual SQA plan for the Android HRM ERG app before Play Store release.

It covers:
- BLE heart rate monitors
- FTMS smart trainers
- First-run permissions
- Reconnect and stale-data handling
- Ride safety when Bluetooth data stops

## Status Model To Verify

These labels should match the app UI.

### Trainer Status

| Status | Meaning |
| --- | --- |
| Disconnected | Trainer is not connected |
| Scanning | App is searching for a trainer |
| Connecting | App is establishing a connection |
| Connected | Trainer is connected and telemetry is flowing |
| Connected (no response) | Trainer is connected but not sending fresh telemetry |
| Reconnecting | Trainer connection was lost and the app is retrying |

### HR Monitor Status

| Status | Meaning |
| --- | --- |
| Disconnected | HR monitor is not connected |
| Scanning | App is searching for an HR monitor |
| Connecting | App is establishing a connection |
| Connected | HR data is flowing normally |
| Connected (no HR data) | HR monitor is connected but fresh HR samples are missing |
| Reconnecting | HR monitor connection was lost and the app is retrying |

## Test Environments

### Emulator / Mock Mode

Use:

```powershell
flutter run -d <emulator_id> --dart-define=USE_MOCK_DEVICES=true
```

Use mock controls for:
- connect and disconnect HR
- connect and disconnect trainer
- steady HR
- slow HR rise
- HR dropout
- trainer telemetry stall
- trainer telemetry resume

### Physical Device Runs

Use a real Android phone plus:
- 1 BLE HR chest strap
- 1 FTMS trainer

Recommended minimum matrix:
- Android 11 device
- Android 12+ device
- at least one Pixel or Samsung phone

## Manual Test Checklist

### 1. Permissions

Verify on Android 11:
- App asks for the required Bluetooth/location access before scan/connect
- Deny once and confirm the app stays usable with a clear warning card
- Grant access on retry and confirm scan works immediately after

Verify on Android 12+:
- App asks for Bluetooth scan/connect access before scan/connect
- Deny once and confirm the warning card appears
- Permanently deny and confirm the app offers an Open settings action
- Return from settings after granting access and confirm reconnect/scan works

Pass criteria:
- Scan never starts before permissions are granted
- The app shows clear recovery actions instead of raw plugin errors

### 2. Bluetooth Adapter Readiness

Verify:
- Launch app with Bluetooth already on
- Launch app with Bluetooth off
- Turn Bluetooth off while app is open
- Turn Bluetooth back on and confirm the app recovers

Pass criteria:
- The app shows a Bluetooth-off warning card
- Saved-device reconnect works again after Bluetooth returns

### 3. Device Discovery

Verify:
- HR monitor appears in scan results
- Trainer appears in scan results
- Scan results do not duplicate devices across repeated scans
- Device names are clear enough to distinguish devices

Pass criteria:
- Devices appear within a few seconds when they are advertising

### 4. Initial Connection

Verify:
- Connect HR only
- Connect trainer only
- Connect both devices in either order
- Connect with mock devices enabled
- Failed connect attempts do not freeze the UI

Pass criteria:
- Device status moves through Scanning / Connecting / Connected cleanly

### 5. Live Data And Safety

Verify:
- HR values update continuously once connected
- Trainer power updates from real telemetry, not just the last command
- Cadence appears when the trainer provides it
- HR-ERG control does not run until fresh HR is available
- Power-ERG control pauses if trainer telemetry goes stale

Pass criteria:
- No stale values are presented as fresh
- The ride pauses instead of controlling the trainer from stale data

### 6. Disconnect / Reconnect

Verify each of these during a ride:
- HR strap off
- Trainer off
- Phone Bluetooth off
- Phone Bluetooth back on
- Device moved out of range and back

Pass criteria:
- Rider sees a clear status change
- Session pauses safely
- Reconnect restores streaming data without restarting the app

### 7. Multi-Session Reliability

Verify:
- Finish one ride
- Start a second ride without killing the app
- Reconnect saved devices between rides if needed

Pass criteria:
- Second ride starts and runs normally without app restart

## App-Specific QA Scripts

### Script 1: First-Run Permissions

1. Install fresh build
2. Launch app
3. Deny Bluetooth access
4. Confirm Bluetooth Access Needed card appears
5. Tap Grant access and approve permissions
6. Scan for HR and trainer

Expected:
- Permission card disappears after grant
- Scan works without app restart

### Script 2: Auto Reconnect On Launch

1. Connect HR and trainer once
2. Close app
3. Reopen app with both devices available

Expected:
- Saved device IDs are shown
- Auto reconnect attempts run
- Both devices reach Connected when live data resumes

### Script 3: HR Dropout During HR-ERG

Physical:
1. Start HR-ERG ride
2. Confirm live HR and trainer power
3. Remove HR strap battery contact or power HR device off

Mock:
1. Start HR-ERG ride in mock mode
2. Run Dropout scenario

Expected:
- HR status becomes Connected (no HR data) or disconnected
- Ride pauses with waiting-for-fresh-HR messaging
- Trainer control stops adjusting until HR returns

### Script 4: Trainer Telemetry Stall

Physical:
1. Start a ride
2. Force the trainer to stop responding if possible, or move temporarily out of range

Mock:
1. Start a ride in mock mode
2. Tap Trainer Stall

Expected:
- Trainer status becomes Connected (no response) or disconnected
- Ride pauses with trainer-not-responding messaging
- No further power adjustments are sent while paused
- Trainer Resume or real telemetry recovery returns the ride to active state

### Script 5: Bluetooth Off / On Recovery

1. Start a ride with both devices healthy
2. Turn phone Bluetooth off
3. Wait for pause and status changes
4. Turn Bluetooth back on

Expected:
- App shows Bluetooth Is Off warning
- Device status moves to reconnecting/disconnected states
- Saved-device reconnect recovers when Bluetooth is back on

### Script 6: Second Ride Reliability

1. Complete or stop a ride
2. Start another ride without killing the app
3. Confirm both devices still stream data

Expected:
- Setup remains usable
- Second ride does not require app restart

## Launch Blockers

Do not publish if any of these are still reproducible:
- Trainer power continues changing after HR data stops
- Ride does not pause when trainer telemetry goes stale
- Permissions cannot recover cleanly on Android 12+
- Bluetooth off/on requires app restart
- UI shows Connected while data is clearly dead
- Second ride frequently fails without restart
