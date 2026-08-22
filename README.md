# FreeFire Companion App (iOS)

A production-grade SwiftUI utility and companion application for Garena Free Fire on iOS (iPhone 17, 16, 15, 14, 13 & iPad).

## 🚀 Features

1. **Sens Calculator (`SensitivityView.swift`)**:
   - Calibrated General, Red Dot, 2x, 4x, AWM, and Free Look scope sensitivity generator.
   - Calculates custom Fire Button Size for drag headshots.
   - Includes real-time Aim Stability Index meter and one-tap copy.

2. **Touch Diagnostic (`TouchTestView.swift`)**:
   - Interactive drag test canvas to detect micro-jitter, screen ghost touches, and touch polling drops.

3. **FPS Booster Guide (`PerformanceGuideView.swift`)**:
   - Interactive iOS optimization checklist for Game Mode, Low Power Mode, Touch Accommodations, and Display settings.

4. **Ping Tester (`PingTestView.swift`)**:
   - Real-time network latency and jitter simulator for regional game servers.

---

## 🛠 How to Build & Install on iPhone (iOS)

### Option A: Using Xcode (Official & Recommended)
1. Open **Xcode** on a Mac.
2. Select **Create a new Xcode project** > **App** (SwiftUI).
3. Set Project Name to `FreeFireCompanion` and Bundle Identifier to `com.yourname.FreeFireCompanion`.
4. Replace/Add the files from `c:/Users/AKKi/Downloads/IOS/FreeFireCompanion/` into your Xcode project navigator:
   - `FreeFireCompanionApp.swift`
   - `ContentView.swift`
   - `Models/DeviceProfile.swift`
   - `Views/SensitivityView.swift`
   - `Views/TouchTestView.swift`
   - `Views/PerformanceGuideView.swift`
   - `Views/PingTestView.swift`
5. Connect your iPhone via USB / Wi-Fi, select your device, and click **Run** (`Cmd + R`).

### Option B: Sideloading / IPA Installation (AltStore / Sideloadly)
1. Build the target as `.ipa` in Xcode or Swift CLI.
2. Install via **AltStore** or **Sideloadly** onto your iPhone.
3. On your iPhone, go to **Settings > General > VPN & Device Management** and tap **Trust Developer Certificate**.
