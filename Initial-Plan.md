# Initial Plan: HR-Controlled ERG Flutter App (Android First)

## Summary
- [ ] Build an Android-first Flutter MVP that pairs to a BLE HR monitor and Wattbike Atom, computes a 60-second HR average from 1-second samples, and updates ERG power every 20 seconds.
- [ ] Execute in beginner-friendly phases: environment readiness, project scaffold, BLE integration, control loop, UI, and live validation.
- [ ] Defer non-MVP features (charts, long-term analytics, advanced alerts) until MVP acceptance criteria are met.

## Prerequisites (Do First)
- [ ] Install Flutter SDK (stable) to a user-writable path (example: `C:\Users\melpc\tools\flutter`) and add `...\flutter\bin` to user `PATH`.
- [ ] Install Android Studio (stable) with Android SDK Platform 34, Build-Tools, Command-line Tools, Platform-Tools, and Emulator.
- [ ] Set `ANDROID_SDK_ROOT` (default: `C:\Users\melpc\AppData\Local\Android\Sdk`) and ensure `adb` resolves on `PATH`.
- [ ] Install VS Code extensions: `Flutter` and `Dart` (optional: `Error Lens`).
- [ ] Keep Java 11 available (already present) unless `flutter doctor` requires a different toolchain.
- [ ] Run `flutter doctor -v` and clear all Android toolchain blockers.
- [ ] Enable Developer Options + USB debugging on the Android phone and verify via `adb devices`.
- [ ] Confirm both BLE devices are available and discoverable for testing (HR monitor + Wattbike Atom).

## Implementation Changes (MVP, Decision-Complete)
- [ ] Create a new Flutter app scaffold in this repo and commit a clean baseline.
- [ ] Add dependencies: `flutter_blue_plus`, `flutter_riverpod`, `equatable`, `collection`, `intl`.
- [ ] Define core contracts and models.
- [ ] Add `HrSample { bpm, timestamp }`, `PowerCommand { watts, timestamp, reason }`, `ControlConfig { targetHr, minPower=50, maxPower=500, loopSeconds=20, avgWindowSeconds=60 }`.
- [ ] Add `HrMonitorRepository` interface for HR stream + reconnect handling.
- [ ] Add `TrainerRepository` interface for FTMS connection + `setTargetPower(int watts)`.
- [ ] Implement BLE scan/select/connect flow for both device roles and persist selected device IDs for reconnect.
- [ ] Implement HR pipeline: ingest 1 Hz HR samples, maintain rolling 60-second average, and handle sample gaps.
- [ ] Implement control engine logic.
- [ ] Compute `delta = hrAvg - targetHr`.
- [ ] Map delta to W/min (`+1/-3`, `+2/-6`, `>=+3/-10`, `-1/+3`, `-2/+6`, `<=-3/+10`).
- [ ] Convert to per-loop (`adjLoop = adjPerMin / 3`), round to whole watts, and clamp to 50-500 W.
- [ ] Execute control tick every 20 seconds only when trainer is connected and HR freshness is <= 5 seconds.
- [ ] Add safety behavior: pause control on stale HR/disconnect, manual stop, explicit pause reason in UI.
- [ ] Build MVP UI.
- [ ] Create connect screen with scan/select/connect states for HR monitor and Wattbike.
- [ ] Create ride screen with current HR, 60s average HR, target HR control, current power command, loop countdown, and status banners.
- [ ] Add per-session CSV logging (`timestamp, hr, hr_avg, target_hr, delta, power_cmd, status`) to app documents storage.
- [ ] Add structured debug logs around BLE events and each control tick.
- [ ] Create milestone commits after setup, BLE connectivity, control engine, UI, and live validation.

## Test Plan and Acceptance Criteria
- [ ] Unit test rolling 60-second average with normal, sparse, and missing-sample sequences.
- [ ] Unit test delta-to-adjustment mapping and clamp boundaries.
- [ ] Unit test scheduler and stale-HR guard (no command writes when invalid).
- [ ] Integration test (mock repositories) for connect/disconnect/reconnect and pause/resume transitions.
- [ ] Live test: steady HR near target, verify stable/limited power oscillation.
- [ ] Live test: sustained HR above target, verify expected progressive power reduction.
- [ ] Live test: HR dropout, verify safe pause and no control writes.
- [ ] Live test: trainer disconnect/reconnect, verify safe recovery and controlled resume.
- [ ] MVP exit criteria: 30-minute real ride without app crash, with complete session log and expected control behavior.

## Assumptions and Defaults
- [ ] Android-only MVP (iOS deferred).
- [ ] Scope locked to MVP Control Loop for first release.
- [ ] Hardware is available now for immediate real-device BLE validation.
- [ ] Riverpod is the default state management approach.
- [ ] Timing and adjustment table values are fixed for MVP unless safety validation requires change.
