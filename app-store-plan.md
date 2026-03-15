# App Store Plan

This document is the store-readiness plan for `android-hrm-erg`.

Current branding:

- App name: `Zone 2 Cycling by Heart`
- Short description: `Heart-rate guided Zone 2 ERG training for indoor cycling`

It is split into two passes:

1. Pass 1: repo work for telemetry, diagnostics, support UX, and release preparation.
2. Pass 2: manual Play Console, signing, listing, privacy, and rollout work.

## Current Launch Blockers In This Repo

- Firebase is optional in code, but there is no `google-services.json` or Android Firebase plugin wiring yet.
- Support email and privacy policy values are placeholders in the UI.
- Google Play listing assets are only partially ready:
  - launcher icon exists
  - short description exists
  - long description exists
  - screenshots and feature graphic are still missing
- No signed `.aab` has been built and tested on a clean release configuration.

## What Is Already Implemented

- Anonymous telemetry hooks for app lifecycle, BLE setup, connect/reconnect, workout usage, and diagnostics export.
- Local diagnostics storage with runtime events, session files, export generation, retention pruning, and corruption hardening.
- Support UI with `Support`, `Export diagnostics`, `App info`, and detailed workout information menu items.
- On-device diagnostics export flow using the Android share sheet.
- BLE reliability improvements:
  - scan/connect overlap reduction
  - trainer FTMS preparation retries
  - HR strap scan retry and user guidance
- Branding updates:
  - app display name updated to `Zone 2 Cycling by Heart`
  - simplified red `Z2` launcher icon
  - store copy added to `Store-description.md`
- Android application ID updated to `com.melcollins.zone2cyclingbyheart`
- Release upload keystore created and wired through `android/key.properties`

## Anonymous Telemetry And Metrics Design

### Backend sources

- `Firebase Analytics`: product and operational event counts.
- `Firebase Crashlytics`: fatal and non-fatal app issues.
- `Google Play Vitals`: crashes, ANRs, and device-specific stability issues.

### Backend event rules

- Backend telemetry must stay anonymous.
- Do not send raw BLE device IDs.
- Do not send raw BLE device names.
- Do not send raw HR streams or raw power streams.
- Common event properties:
  - `session_id`
  - `workout_type`
  - `device_role`
  - `trigger`
  - `result`
  - `pause_reason`
  - `app_version`
  - `build_number`
  - `android_api`
  - `phone_model`

### Events to monitor

- App lifecycle:
  - `app_started`
  - framework/platform/zone errors
- Bluetooth setup:
  - `ble_permission_request`
  - `ble_permission_result`
  - `ble_adapter_state`
  - `ble_scan_started`
  - `ble_scan_completed`
  - `ble_connect_attempt`
  - `ble_connect_result`
  - `ble_reconnect_attempt`
  - `ble_reconnect_result`
  - `ble_status_change`
  - `ble_stale_detected`
- Workout usage:
  - `workout_selected`
  - `workout_started`
  - `workout_paused`
  - `workout_resumed`
  - `workout_manual_stop`
  - `workout_completed`
  - `workout_summary`
- Support:
  - `diagnostics_export_attempt`
  - `diagnostics_export_result`

### Metrics worth watching after launch

- Crash-free sessions.
- ANR rate.
- Internal-test install to first successful ride.
- BLE connect success rate by device role.
- BLE reconnect success rate by device role.
- `connectedNoData` / stale-data rate for HR and trainer.
- Permission denial and permanently-denied rate.
- Workout type selected counts.
- Workout start counts by program.
- Workout completion counts by program.
- Manual stop rate by program.
- Pause reason counts:
  - `staleHr`
  - `hrDisconnected`
  - `trainerDisconnected`
  - `trainerStale`
- Diagnostics export usage rate.

## Local Diagnostics Export Workflow

### On-device storage

- Runtime events: `diagnostics/runtime.jsonl`
- Session records: `diagnostics/sessions/<session_id>.json`
- Exports: `diagnostics/exports/*.json`
- Retention: keep the newest 20 session files

### What stays local until the user exports

- Saved BLE device IDs
- Saved BLE device names
- Richer BLE troubleshooting detail
- Recent runtime event history
- The last 20 workout sessions with local diagnostics details

### User support flow

1. User opens the app bar menu.
2. User taps `Export diagnostics`.
3. App builds a redacted-but-richer support JSON file locally.
4. Android share sheet opens.
5. User chooses how to send the file to support.

### Current placeholders to replace before production

- Support email: `support@example.com`
- Privacy policy URL: `https://example.com/privacy-policy`

## Data Safety / Privacy Mapping

### Data collected by backend telemetry

- App info and coarse device info.
- Anonymous usage events.
- Anonymous BLE success/failure counts.
- Crash and stability events.

### Data not sent to backend

- Raw HR samples
- Raw power samples
- Raw BLE device IDs
- Raw BLE device names
- User account data
- Payment data

### Data that can appear in exported diagnostics

- Saved device IDs and friendly names
- Recent runtime event logs
- Recent session logs
- Error strings useful for support

### Play Console declarations to complete

- Data Safety form
- App content declarations
- Health/Fitness positioning
- No-ads declaration if still true at launch
- Privacy policy link

## Manual Google Play Internal-Test Checklist

### Identity and packaging

- Final Android package name is `com.melcollins.zone2cyclingbyheart`.
- Android namespace and Kotlin package paths are updated to match.
- App display name is now set to `Zone 2 Cycling by Heart`.
- Increment `version` / `versionCode` for release.

### Firebase and release wiring

- Create the Firebase project.
- Add the Android app entry.
- Download `google-services.json`.
- Add Android Firebase plugin wiring once the file exists.
- Verify Firebase initializes on a physical device.

### Signing

- Upload keystore has been created locally.
- Store credentials securely outside source control.
- Release signing config is wired through `android/key.properties`.
- Enable Play App Signing in Play Console.

### Store listing

- Create the Play Console app.
- Add short description and full description.
- Current draft copy already exists in `Store-description.md`.
- Add support email.
- Publish privacy policy.
- Prepare screenshots:
  - device setup
  - workout setup
  - live workout
  - summary screen
- Add feature graphic and final icon if needed.

### Submission and rollout

- Build a signed release bundle:
  - `flutter build appbundle --release`
- Upload to `Internal testing`.
- Add tester emails or a Google Group.
- Fill release notes.
- Review pre-launch report results.
- Review Firebase and Play Vitals after testers install.
- Fix blockers before moving to Closed testing or Production.

## Post-Launch Dashboard And Alert Recommendations

### Dashboard

- Daily installs and active testers.
- Crash-free sessions.
- ANR rate.
- BLE connect success rate for HR and trainer.
- BLE reconnect success rate.
- Workout started vs completed by type.
- Pause reasons over time.
- Diagnostics export count.

### Alerts

- Crash-free sessions drop below target.
- ANR rate crosses Play bad-behavior thresholds.
- BLE connect success rate falls sharply after a release.
- Reconnect failures spike on a specific Android version.
- One workout type shows a sudden completion-rate drop.

## Suggested Release Gate

Do not promote beyond internal testing until all of these are true:

- Signed `.aab` builds successfully.
- Firebase is wired and receiving events.
- Privacy policy is live.
- Placeholder support and privacy values are replaced.
- Store listing reflects the final app name `Zone 2 Cycling by Heart`.
- Bluetooth SQA manual checklist passes on physical devices.
- At least one successful end-to-end ride is completed for:
  - `HR-ERG`
  - `Power-ERG`
  - `Zone 2 Assessment`
