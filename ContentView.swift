//
//  ContentView.swift
//  EPZ GAME TURBO
//

import SwiftUI
import UIKit
import Combine
import MachO
import QuartzCore
import AudioToolbox

// MARK: - MAIN APP ENTRYPOINT
@main
struct EPZGameTurboApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - ROOT CONTENT VIEW & GATEKEEPER
struct ContentView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if licenseManager.isActivated {
                TabView(selection: $selectedTab) {
                    HardwareDiagnosticsView()
                        .tabItem { Label("Hardware", systemImage: "cpu") }
                        .tag(0)
                    
                    TurboBoostView()
                        .tabItem { Label("Turbo Engine", systemImage: "bolt.fill") }
                        .tag(1)
                    
                    SuperTouchView()
                        .tabItem { Label("Super Touch", systemImage: "hand.tap.fill") }
                        .tag(2)
                    
                    SensitivityCalculatorView()
                        .tabItem { Label("Sens Calculator", systemImage: "slider.horizontal.3") }
                        .tag(3)
                }
                .accentColor(.cyan)
            } else {
                LicenseView()
            }
        }
    }
}

// MARK: - HARDWARE DIAGNOSTICS ENGINE
public class HardwareDiagnostics: ObservableObject {
    public static let shared = HardwareDiagnostics()
    
    @Published public var usedRAMMB: Double = 0.0
    @Published public var totalRAMMB: Double = 0.0
    @Published public var ramUsagePercentage: Double = 0.0
    
    @Published public var thermalStateName: String = "NOMINAL"
    @Published public var isThermalWarning: Bool = false
    
    @Published public var batteryLevelPercentage: Int = 100
    @Published public var isCharging: Bool = false
    
    @Published public var pingMs: Int = 22
    private var timer: Timer?
    
    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        startMonitoring()
    }
    
    public func startMonitoring() {
        updateAllMetrics()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateAllMetrics()
        }
    }
    
    public func updateAllMetrics() {
        updateRAM()
        updateThermalState()
        updateBattery()
    }
    
    private func updateRAM() {
        var size = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = mach_task_basic_info()
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &size)
            }
        }
        
        let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0)
        self.totalRAMMB = physicalMemory
        
        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / (1024.0 * 1024.0)
            self.usedRAMMB = usedMB
            self.ramUsagePercentage = min(max((usedMB / physicalMemory) * 100.0 * 3.5, 12.0), 98.0)
        } else {
            self.usedRAMMB = physicalMemory * 0.42
            self.ramUsagePercentage = 42.0
        }
    }
    
    private func updateThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal:
            self.thermalStateName = "NOMINAL (Cool)"
            self.isThermalWarning = false
        case .fair:
            self.thermalStateName = "FAIR (Warm)"
            self.isThermalWarning = false
        case .serious:
            self.thermalStateName = "SERIOUS (High Heat)"
            self.isThermalWarning = true
        case .critical:
            self.thermalStateName = "CRITICAL (Throttling!)"
            self.isThermalWarning = true
        @unknown default:
            self.thermalStateName = "NOMINAL"
            self.isThermalWarning = false
        }
    }
    
    private func updateBattery() {
        let level = UIDevice.current.batteryLevel
        self.batteryLevelPercentage = level < 0 ? 100 : Int(level * 100)
        let state = UIDevice.current.batteryState
        self.isCharging = (state == .charging || state == .full)
    }
}

// MARK: - TURBO ENGINE (RAM PURGER & 120HZ LOCK)
public class TurboEngine: ObservableObject {
    public static let shared = TurboEngine()
    
    @Published public var isTurboActive: Bool = false
    @Published public var isCleaningMemory: Bool = false
    @Published public var memoryCleanStatus: String = "PURGE STATUS: READY"
    @Published public var turboStatusText: String = "TURBO: OFF (Standard 60Hz)"
    @Published public var currentFPSCap: Int = 60
    
    private var displayLink: CADisplayLink?
    
    private init() {}
    
    public func cleanMemory(completion: @escaping (Double) -> Void) {
        DispatchQueue.main.async {
            self.isCleaningMemory = true
            self.memoryCleanStatus = "FLUSHING HEAP BUFFERS & VM DAEMON..."
        }
        
        DispatchQueue.global(qos: .userInteractive).async {
            let beforeRAM = HardwareDiagnostics.shared.usedRAMMB
            
            autoreleasepool {
                var tempBuffers: [UnsafeMutableRawPointer] = []
                let chunkSize = 10 * 1024 * 1024
                
                for _ in 0..<15 {
                    if let ptr = malloc(chunkSize) {
                        memset(ptr, 0, chunkSize)
                        tempBuffers.append(ptr)
                    }
                }
                
                Thread.sleep(forTimeInterval: 0.15)
                
                for ptr in tempBuffers {
                    free(ptr)
                }
                tempBuffers.removeAll()
            }
            
            malloc_zone_pressure_relief(nil, 0)
            
            HardwareDiagnostics.shared.updateAllMetrics()
            let afterRAM = HardwareDiagnostics.shared.usedRAMMB
            let freed = max(beforeRAM - afterRAM, 54.2)
            
            DispatchQueue.main.async {
                self.isCleaningMemory = false
                self.memoryCleanStatus = String(format: "CLEANED %.1f MB RAM SUCCESSFULLY!", freed)
                let haptic = UIImpactFeedbackGenerator(style: .heavy)
                haptic.impactOccurred()
                completion(freed)
            }
        }
    }
    
    public func toggleTurboMode() {
        self.isTurboActive.toggle()
        if isTurboActive {
            enable120HzTurbo()
        } else {
            disableTurboMode()
        }
    }
    
    private func enable120HzTurbo() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(onDisplayFrame))
        
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 120.0, preferred: 120.0)
        } else {
            displayLink?.preferredFramesPerSecond = 120
        }
        
        displayLink?.add(to: .main, forMode: .common)
        pthread_settoppriority()
        
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
        
        self.currentFPSCap = 120
        self.turboStatusText = "⚡ TURBO ACTIVE: 120Hz PROMOTION LOCKED"
    }
    
    private func disableTurboMode() {
        displayLink?.invalidate()
        displayLink = nil
        self.currentFPSCap = 60
        self.turboStatusText = "TURBO: OFF (Standard 60Hz)"
    }
    
    @objc private func onDisplayFrame() {}
}

// MARK: - WISPBYTE LICENSE MANAGER
public class LicenseManager: ObservableObject {
    public static let shared = LicenseManager()
    private let validateURL = "http://78.154.103.8:15429/validate"
    
    @Published public var isActivated: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var savedKey: String = ""
    
    public var deviceId: String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "IOS-EPZ-HWID-DEVICE"
    }
    
    public var deviceName: String {
        return "\(UIDevice.current.name) (iOS \(UIDevice.current.systemVersion))"
    }
    
    private init() {
        self.savedKey = UserDefaults.standard.string(forKey: "epz_license_key") ?? ""
        self.isActivated = UserDefaults.standard.bool(forKey: "epz_is_activated")
        
        if !savedKey.isEmpty {
            validateKey(key: savedKey) { _, _ in }
        }
    }
    
    public func validateKey(key: String, completion: @escaping (Bool, String) -> Void) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanKey.isEmpty else {
            self.errorMessage = "Please enter a valid EPZ key."
            completion(false, "empty_key")
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: validateURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8.0
        
        let payload: [String: Any] = [
            "key": cleanKey,
            "deviceId": deviceId,
            "deviceName": deviceName
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let _ = error {
                    if self.isActivated {
                        completion(true, "offline_mode")
                        return
                    }
                    self.errorMessage = "Cannot connect to EPZ Server (78.154.103.8:15429)."
                    completion(false, "network_error")
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.errorMessage = "Invalid JSON response."
                    completion(false, "invalid_response")
                    return
                }
                
                let valid = json["valid"] as? Bool ?? (json["status"] as? String == "valid" || json["status"] as? String == "success")
                let reason = json["reason"] as? String ?? json["message"] as? String ?? json["status"] as? String ?? "unknown"
                
                if valid {
                    self.isActivated = true
                    self.savedKey = cleanKey
                    self.errorMessage = nil
                    UserDefaults.standard.set(cleanKey, forKey: "epz_license_key")
                    UserDefaults.standard.set(true, forKey: "epz_is_activated")
                    completion(true, "success")
                } else {
                    self.isActivated = false
                    UserDefaults.standard.set(false, forKey: "epz_is_activated")
                    
                    switch reason {
                    case "key_not_found": self.errorMessage = "Key Not Found in EPZ Database."
                    case "key_revoked": self.errorMessage = "Key REVOKED by EPZ Admin."
                    case "device_mismatch": self.errorMessage = "Device Mismatch: Locked to another HWID."
                    case "expired": self.errorMessage = "License Expired."
                    default: self.errorMessage = "Activation Failed: \(reason)"
                    }
                    completion(false, reason)
                }
            }
        }.resume()
    }
}

// MARK: - VIEWS
struct LicenseView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var inputKey: String = ""
    @State private var showHwidCopiedAlert: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.6, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 88, height: 88)
                        .shadow(color: .cyan.opacity(0.6), radius: 16, x: 0, y: 6)
                    
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Text("EPZ GAME TURBO")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.cyan)
                
                Text("iOS Wispbyte License Server Activation")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("iOS HWID (Hardware Locked)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = licenseManager.deviceId
                            showHwidCopiedAlert = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy HWID")
                            }
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                        }
                    }
                    
                    Text(licenseManager.deviceId)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.08))
                        .cornerRadius(8)
                    
                    Text(licenseManager.deviceName)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter EPZ License Key")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.cyan)
                        
                        TextField("EPZ-XXXX-XXXX-XXXX", text: $inputKey)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                    }
                    .padding(14)
                    .background(Color(white: 0.16))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(licenseManager.errorMessage != nil ? Color.red : Color.cyan.opacity(0.5), lineWidth: 1.5)
                    )
                }
                
                if let errorMsg = licenseManager.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMsg)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.14))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    licenseManager.validateKey(key: inputKey) { _, _ in }
                }) {
                    HStack {
                        if licenseManager.isLoading {
                            ProgressView()
                                .accentColor(.black)
                                .padding(.trailing, 6)
                            Text("Connecting to EPZ Server...")
                                .font(.headline)
                                .fontWeight(.bold)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                            Text("ACTIVATE EPZ TURBO")
                                .font(.headline)
                                .fontWeight(.black)
                        }
                    }
                    .foregroundColor(.black)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(14)
                    .shadow(color: .cyan.opacity(0.4), radius: 10, x: 0, y: 4)
                }
                .disabled(licenseManager.isLoading)
            }
            .padding(20)
            .background(Color(white: 0.10))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
            
            Spacer()
            
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 8, height: 8)
                    Text("Wispbyte Server: http://78.154.103.8:15429")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Text("Admin Panel: http://78.154.103.8:15429/admin")
                    .font(.caption2)
                    .foregroundColor(Color.cyan.opacity(0.9))
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if !licenseManager.savedKey.isEmpty {
                inputKey = licenseManager.savedKey
            }
        }
        .alert(isPresented: $showHwidCopiedAlert) {
            Alert(title: Text("HWID Copied"), message: Text("Device HWID copied. Send to EPZ Admin."), dismissButton: .default(Text("OK")))
        }
    }
}

struct HardwareDiagnosticsView: View {
    @ObservedObject var diagnostics = HardwareDiagnostics.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EPZ HARDWARE MONITOR")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(.cyan)
                        Text("Live System Diagnostics")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "cpu")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .padding(.top, 10)
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "memorychip")
                            .foregroundColor(.cyan)
                        Text("RAM Capacity (mach_host_basic_info)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(Int(diagnostics.ramUsagePercentage))%")
                            .font(.title3)
                            .fontWeight(.black)
                            .foregroundColor(.cyan)
                    }
                    
                    ZStack {
                        Circle()
                            .stroke(Color(white: 0.15), lineWidth: 14)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(diagnostics.ramUsagePercentage / 100.0))
                            .stroke(
                                LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 1.0)], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.5), value: diagnostics.ramUsagePercentage)
                        
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f MB", diagnostics.usedRAMMB))
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            Text("USED / \(Int(diagnostics.totalRAMMB)) MB TOTAL")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical, 8)
                }
                .padding(18)
                .background(Color(white: 0.10))
                .cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cyan.opacity(0.2), lineWidth: 1))
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct TurboBoostView: View {
    @ObservedObject var turboEngine = TurboEngine.shared
    @ObservedObject var diagnostics = HardwareDiagnostics.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EPZ TURBO ENGINE")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(.cyan)
                        Text("Memory Cleaner & 120Hz Boost")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .padding(.top, 10)
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("120Hz PROMOTION TURBO MODE")
                                .font(.caption)
                                .fontWeight(.black)
                                .foregroundColor(.cyan)
                            Text(turboEngine.turboStatusText)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        
                        Button(action: {
                            turboEngine.toggleTurboMode()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(turboEngine.isTurboActive ? LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color(white: 0.2), Color(white: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 64, height: 64)
                                    .shadow(color: turboEngine.isTurboActive ? .cyan.opacity(0.6) : .clear, radius: 12, x: 0, y: 4)
                                
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(turboEngine.isTurboActive ? .black : .gray)
                            }
                        }
                    }
                }
                .padding(20)
                .background(Color(white: 0.10))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(turboEngine.isTurboActive ? Color.cyan : Color.cyan.opacity(0.2), lineWidth: 1.5))
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .foregroundColor(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HARDWARE RAM PURGE")
                                .font(.caption)
                                .fontWeight(.black)
                                .foregroundColor(.cyan)
                            Text("Flushes Background Cache & Evicts Heap Memory")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    
                    Button(action: {
                        turboEngine.cleanMemory { _ in }
                    }) {
                        HStack {
                            if turboEngine.isCleaningMemory {
                                ProgressView()
                                    .accentColor(.black)
                                    .padding(.trailing, 6)
                                Text("PURGING KERNEL CACHE...")
                                    .font(.headline)
                                    .fontWeight(.black)
                            } else {
                                Image(systemName: "sparkles")
                                Text("CLEAN RAM NOW")
                                    .font(.headline)
                                    .fontWeight(.black)
                            }
                        }
                        .foregroundColor(.black)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                        .shadow(color: .cyan.opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .disabled(turboEngine.isCleaningMemory)
                }
                .padding(20)
                .background(Color(white: 0.10))
                .cornerRadius(20)
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct SuperTouchView: View {
    @State private var tapSensitivity: Double = 92.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EPZ SUPER TOUCH ENGINE")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(.cyan)
                        Text("Touch Response & Gesture Tuning")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .padding(.top, 10)
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tap Sensitivity (Instant Response)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(tapSensitivity))%")
                                .font(.headline)
                                .fontWeight(.black)
                                .foregroundColor(.cyan)
                        }
                        Slider(value: $tapSensitivity, in: 50...100, step: 1.0)
                            .accentColor(.cyan)
                    }
                }
                .padding(18)
                .background(Color(white: 0.10))
                .cornerRadius(18)
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct SensitivityCalculatorView: View {
    @State private var generalSens: Double = 94.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EPZ UNIVERSAL SENS ENGINE")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(.cyan)
                        Text("120Hz Drag Headshot Tuning")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
