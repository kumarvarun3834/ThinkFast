# ThinkFast Robo-Testing Error Logs

## Session: 2026-07-01

### 🌐 Network & Firebase (All Emulators)
- **Warning**: `Firestore: GaiException: android_getaddrinfo failed: EAI_NODATA`.
  - *Details*: Observed intermittent DNS resolution failures on emulators. App handled gracefully (re-attempted connection).
- **Warning**: `FirebaseMessaging: Default FirebaseApp has not been initialized`.
  - *Details*: Occurred once on `emulator-5558` during quick start/stop cycles.

### 🛠 System Level (Non-App)
- **Error**: `BluetoothPowerStatsCollector: java.util.concurrent.ExecutionException: java.lang.RuntimeException: error: 11`.
  - *Details*: Emulator system-level bluetooth error, unrelated to ThinkFast app code.
- **Error**: `WifiChipAidlImpl: getUsableChannels failed with service-specific exception`.
  - *Details*: Emulator hardware abstraction failure.

### 🐒 Monkey Test Results
- **Emulator-5554**: 100 events injected. **0 Crashes**.
- **Emulator-5556**: 100 events injected. **0 Crashes**.
- **Emulator-5558**: 100 events injected. **0 Crashes**.

### 📉 UI/Layout Issues
- **None Found**: No `RenderFlex` overflow errors or framework assertions detected in logcat during stress tests.
