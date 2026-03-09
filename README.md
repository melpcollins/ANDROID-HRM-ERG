# Android HRM ERG

Heart-rate-driven ERG control app for Android (Flutter).  
The app connects to a Bluetooth HR monitor and Bluetooth trainer, then adjusts trainer power to hold a target heart rate.

## What It Does
- Connects to HRM + trainer over BLE
- Saves selected devices and attempts reconnect on startup
- Runs ERG control loop using a 10-second HR average window
- Uses a configurable loop interval (seconds)
- Live metrics: HR average, target HR, power, drift
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
3. In `ERG Control`, set `Starting Watts`, `Target Heart Rate`, and `Loop Interval (seconds)`.
4. Tap `Start`.
5. Monitor live metrics during ride.

## Project Structure
- `lib/src/infrastructure/ble`: BLE repositories (HRM + trainer)
- `lib/src/application/connect`: connect/reconnect state logic
- `lib/src/application/session`: ERG session + control loop logic
- `lib/src/app.dart`: main UI
- `use cases/`: scenario docs for feature-level discussions

## Troubleshooting
- Device not found: ensure BLE device is awake and advertising, keep phone close, then re-run `Scan`.
- App install blocked (`ADB` restricted): enable USB debugging and allow install prompts on phone.
- Trainer connected but power not changing: reconnect trainer, restart session, and confirm FTMS control-point support.
- Screen locking during ride: app sets keep-screen-on in `MainActivity.kt`; verify app is foregrounded.
