# Android HRM ERG

Physiology-driven indoor cycling app for Android (Flutter).  
The app connects to a Bluetooth HR monitor and Bluetooth trainer, then supports both heart-rate-controlled ERG rides and fixed-protocol Zone 2 assessment rides.

## What It Does
- Connects to HRM + trainer over BLE
- Saves selected devices and attempts reconnect on startup
- Supports two workout modes: `HR-ERG` and `Zone 2 Assessment`
- Runs HR-ERG control using a 10-second HR average window and 5-second loop
- Pauses workouts automatically on stale HR or device disconnect until data is valid again
- Shows live session status plus post-ride power-fade, aerobic-drift, and Zone 2 guidance
- Keeps screen awake during long rides

## Prerequisites
- Flutter SDK (stable) installed and on `PATH`
- Android Studio + Android SDK
- Physical Android phone (USB debugging enabled)
- BLE HR monitor + BLE trainer available

Quick verification:

```powershell
flutter doctor -v
flutter devices
```

## Install Dependencies

```powershell
flutter pub get
```

## Run The App (Phone)
Connect phone via USB and make sure it appears in `flutter devices`, then run:

```powershell
flutter run -d <device_id>
```

Example:

```powershell
flutter run -d 2a99c10d
```

Non-resident mode (install + launch, then return terminal):

```powershell
flutter run -d <device_id> --no-resident
```

## Emulator-First Debugging

For UI and workout-logic bugs, use the Android emulator with mock devices instead of the phone:

```powershell
flutter emulators --launch Medium_Phone_API_36.1
flutter devices
flutter run -d <emulator_id> --dart-define=USE_MOCK_DEVICES=true
```

In mock mode the app shows a `Mock Controls` panel that can:
- connect/disconnect mock HR and trainer devices
- emit steady HR
- run `Steady`, `Slow Rise`, and `Dropout` HR scenarios
- reconnect the trainer and reset mock state

Use the physical phone for real BLE issues such as FTMS quirks, hardware reconnect behavior, or scan reliability with actual peripherals.

## Test And Lint

```powershell
flutter analyze
flutter test
```

## Build APK

Debug APK:

```powershell
flutter build apk --debug
```

Release APK:

```powershell
flutter build apk --release
```

Output:

- `build/app/outputs/flutter-apk/app-debug.apk`
- `build/app/outputs/flutter-apk/app-release.apk`

## Install APK Manually (ADB)

```powershell
adb -s <device_id> install -r build\app\outputs\flutter-apk\app-debug.apk
```

If `adb` is not on `PATH`, use:

`C:\Users\<you>\AppData\Local\Android\sdk\platform-tools\adb.exe`

## Typical Session Flow
1. Open app, let auto-reconnect try saved devices (up to 3 times).
2. If needed, use `Scan` / `Reconnect saved` for HRM and trainer.
3. Choose `HR-ERG` or `Zone 2 Assessment`.
4. Enter the workout-specific setup values and tap `Start`.
5. Monitor live status during the ride, then review the summary during cooldown or after completion.

## Project Structure
- `lib/src/infrastructure/ble`: BLE repositories (HRM + trainer)
- `lib/src/application/connect`: connect/reconnect state logic
- `lib/src/application/session`: shared workout session engine, analytics, and control logic
- `lib/src/app.dart`: main UI
- `use-cases/`: scenario docs for feature-level discussions

## Troubleshooting
- Device not found: ensure BLE device is awake and advertising, keep phone close, then re-run `Scan`.
- App install blocked (`ADB` restricted): enable USB debugging and allow install prompts on phone.
- Trainer connected but power not changing: reconnect trainer, restart session, and confirm FTMS control-point support.
- Screen locking during ride: app sets keep-screen-on in `MainActivity.kt`; verify app is foregrounded.
