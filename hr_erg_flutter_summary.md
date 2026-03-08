# HR-ERG Flutter App Summary

This document summarizes the key points and features discussed for building a **Heart-Rate-Controlled ERG app** for the **Wattbike Atom** using **Flutter** in VS Code. It is designed as a reference for development with Codex.

---

## 1. Overview
- Goal: Build a mobile app that reads heart rate (HR) from a BLE HR monitor and adjusts Wattbike Atom power dynamically.
- Control logic: HR-driven ERG, updating every 20 seconds, averaging HR over the last 60 seconds.
- Platform: Android (modern versions), using Flutter for cross-platform capability.
- BLE Protocols: FTMS (Fitness Machine Service) for Wattbike Atom, BLE Heart Rate Service for HR monitor.

---

## 2. Core Features

### 2.1 HR Monitoring
- Connect to BLE HR monitor.
- Read HR once per second.
- Maintain a 60-second moving average (`HR_avg`).

### 2.2 HR-to-Power Logic
- Target HR set by user (Zone 2 example: 135 bpm).
- Calculate delta: `delta = HR_avg - targetHR`
- Adjust power gradually based on delta:

| Delta (bpm) | Power Adjustment (W/min) |
|-------------|-------------------------|
| +1          | -3                      |
| +2          | -6                      |
| +3 or more  | -10                     |
| -1          | +3                      |
| -2          | +6                      |
| -3 or less  | +10                     |

- Scale per 20-second loop: `adj_loop = adj_per_min / 3`
- Clamp power to safe range (example 50–500 W).

### 2.3 FTMS Connection to Wattbike Atom
- Use BLE to connect to Wattbike Atom.
- Send power commands every 20 seconds.
- Supports ERG mode for precise power control.
- App handles reconnection if BLE drops.

### 2.4 User Interface
- Display real-time:
  - Current HR
  - Target HR
  - Current power
- Optional graphs:
  - HR vs target
  - Power vs target
  - HR drift over time
- Alerts for HR above/below target.

### 2.5 Optional Analytics
- Log HR, power, and timestamps for **Pa:Hr decoupling** analysis.
- Track aerobic endurance improvements over weeks/months.

---

## 3. Technical Stack

| Component       | Technology/Package                  |
|-----------------|------------------------------------|
| Flutter SDK      | Cross-platform UI toolkit           |
| Dart            | Programming language                |
| BLE Communication | `flutter_blue_plus`                |
| Graphing/Charts | `fl_chart` or `charts_flutter`     |
| State Management| `provider` or `riverpod`           |
| Loop/Timers     | Dart `Timer`                        |

---

## 4. Android Requirements

- Android 4.3+ supports BLE (FTMS works on all modern phones).
- Android 6+: location permission required to scan BLE.
- Android 12+: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` runtime permissions.
- Developer mode + USB debugging required for testing on a physical phone.
- Optionally, wireless debugging via ADB can be used.

---

## 5. Flutter Development in VS Code

- VS Code is lightweight and supports Flutter development with:
  - Hot reload for instant UI updates
  - Integrated debugger
  - Terminal for `flutter run` and logs
- No admin rights needed for Flutter and VS Code itself.
- Android SDK can be installed in user directory (no admin required).
- Use `flutter doctor` to verify environment setup.

---

## 6. Workflow Diagram

```text
[HR Monitor] --> BLE --> App --> store HR history
[Wattbike Atom] <-- BLE <-- App <-- send power adjustments
Logic Loop (every 20 sec):
1. Compute 60-sec HR_avg
2. Calculate delta vs target HR
3. Determine power adjustment
4. Clamp to limits
5. Send to Atom
6. Update UI & logs
Repeat
```

---

## 7. Optional Enhancements

- Auto-reconnect BLE devices
- User-selectable HR zones
- Configurable power adjustment table
- Real-time alerts/notifications
- Long-term HR drift and aerobic adaptation analytics

---

## 8. Development Notes

- Begin with a minimal Flutter skeleton:
  - BLE connection to HR monitor
  - BLE connection to Wattbike Atom
  - 60-second HR moving average
  - 20-second HR → power loop
  - Real-time UI display
- Gradually add graphs, logging, and analytics.

---

## References
- [Flutter Docs](https://flutter.dev/docs)
- [Flutter Blue Plus](https://pub.dev/packages/flutter_blue_plus)
- [Wattbike Atom BLE FTMS](https://support.wattbike.com/hc/en-gb/articles/4406587641511-Wattbike-Atom-FTMS-Protocol)
- [Pa:Hr Decoupling Concept](https://www.trainingpeaks.com/blog/power-to-heart-rate-decoupling-a-simple-tool-for-monitoring-aerobic-endurance/)

---

*This file is intended as a development blueprint for building a HR-ERG app on Flutter in VS Code, targeting Wattbike Atom and BLE he