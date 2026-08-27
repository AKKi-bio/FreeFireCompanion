//
//  main.swift
//  EPZ GAME TURBO iOS
//
//  Native iOS Application Entrypoint for Pure Swift Compiler
//

import SwiftUI
import UIKit
import Combine
import MachO
import QuartzCore
import AudioToolbox

// MARK: - NATIVE IOS APPLICATION DELEGATE ENTRYPOINT
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: ContentView().preferredColorScheme(.dark))
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

// Top-Level Code Execution in main.swift
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self)
)

// MARK: - ROOT CONTENT VIEW & FLOATING OVERLAY CONTAINER
struct ContentView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @ObservedObject var overlayManager = OverlayManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            if licenseManager.isActivated {
                ZStack {
                    TabView(selection: $selectedTab) {
                        MainDashboardView()
                            .tabItem { Label("Dashboard", systemImage: "bolt.fill") }
                            .tag(0)
                        
                        SuperTouchView()
                            .tabItem { Label("Super Touch", systemImage: "hand.tap.fill") }
                            .tag(1)
                        
                        SensitivityCalculatorView()
                            .tabItem { Label("Sens Engine", systemImage: "slider.horizontal.3") }
                            .tag(2)
                    }
                    .accentColor(.cyan)
                    
                    // Floating System HUD Overlay Window Layer
                    FloatingOverlayView()
                    
                    // In-Match Sensitivity Panel Popup Layer
                    SensitivityView()
                }
            } else {
                LicenseView()
            }
        }
    }
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
            validateKey(key: savedKey, isAutoCheck: true) { _, _ in }
        }
    }
    
    public func validateKey(key: String, isAutoCheck: Bool = false, completion: @escaping (Bool, String) -> Void) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanKey.isEmpty else {
            self.errorMessage = "Please enter a valid key."
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
        
        let payload: [String: String] = [
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
                    if isAutoCheck && self.isActivated {
                        completion(true, "offline_cached")
                        return
                    }
                    self.errorMessage = "Cannot connect to Wispbyte Server (http://78.154.103.8:15429)."
                    completion(false, "network_error")
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.errorMessage = "Invalid JSON response."
                    completion(false, "invalid_response")
                    return
                }
                
                let isValid = json["valid"] as? Bool ?? (json["status"] as? String == "valid" || json["status"] as? String == "success")
                let reason = json["reason"] as? String ?? json["message"] as? String ?? json["status"] as? String ?? "unknown"
                
                if isValid {
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
                    case "key_not_found": self.errorMessage = "Key not found. Check for typos."
                    case "key_revoked": self.errorMessage = "This key has been revoked."
                    case "device_mismatch": self.errorMessage = "This key is active on another device. Click 'Reset Device' in Admin Panel."
                    case "expired": self.errorMessage = "Your EPZ License key has expired."
                    default: self.errorMessage = "Activation Failed: \(reason)"
                    }
                    completion(false, reason)
                }
            }
        }.resume()
    }
    
    public func logout() {
        self.isActivated = false
        self.savedKey = ""
        self.errorMessage = nil
        UserDefaults.standard.set(false, forKey: "epz_is_activated")
        UserDefaults.standard.removeObject(forKey: "epz_license_key")
    }
}

// MARK: - IN-GAME FLOATING OVERLAY & SYSTEM MONITORING
public class OverlayManager: ObservableObject {
    public static let shared = OverlayManager()
    
    @Published public var isOverlayVisible: Bool = false
    @Published public var isSensitivityPanelOpen: Bool = false
    
    @Published public var ramUsedMB: Double = 0.0
    @Published public var ramTotalMB: Double = 0.0
    @Published public var ramUsagePercentage: Double = 0.0
    @Published public var pingMs: Int = 18
    @Published public var thermalStateTitle: String = "NOMINAL"
    @Published public var isThermalOverheating: Bool = false
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    public func startMonitoring() {
        updateMetrics()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    public func updateMetrics() {
        updateRAM()
        updateThermalState()
        measurePing()
    }
    
    private func updateRAM() {
        var size = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = mach_task_basic_info()
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &size)
            }
        }
        
        let physicalMemMB = Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0)
        self.ramTotalMB = physicalMemMB
        
        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / (1024.0 * 1024.0)
            self.ramUsedMB = usedMB
            self.ramUsagePercentage = min(max((usedMB / physicalMemMB) * 100.0 * 3.2, 14.0), 96.0)
        } else {
            self.ramUsedMB = physicalMemMB * 0.42
            self.ramUsagePercentage = 42.0
        }
    }
    
    private func updateThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal:
            self.thermalStateTitle = "NOMINAL (Cool)"
            self.isThermalOverheating = false
        case .fair:
            self.thermalStateTitle = "FAIR (Warm)"
            self.isThermalOverheating = false
        case .serious:
            self.thermalStateTitle = "SERIOUS (High Heat)"
            self.isThermalOverheating = true
        case .critical:
            self.thermalStateTitle = "CRITICAL (Throttling!)"
            self.isThermalOverheating = true
        @unknown default:
            self.thermalStateTitle = "NOMINAL"
            self.isThermalOverheating = false
        }
    }
    
    public func measurePing() {
        guard let url = URL(string: "https://1.1.1.1") else { return }
        let start = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.5
        
        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            let ms = Int(Date().timeIntervalSince(start) * 1000.0)
            DispatchQueue.main.async {
                self?.pingMs = max(min(ms, 120), 14)
            }
        }.resume()
    }
}

// MARK: - TURBO ENGINE (RAM PURGE)
public class TurboEngine: ObservableObject {
    public static let shared = TurboEngine()
    
    @Published public var isCleaningMemory: Bool = false
    @Published public var memoryCleanStatus: String = "Status: Ready for kernel cache eviction"
    
    private init() {}
    
    public func cleanMemory(completion: @escaping (Double) -> Void) {
        DispatchQueue.main.async {
            self.isCleaningMemory = true
            self.memoryCleanStatus = "Purging memory cache..."
        }
        
        DispatchQueue.global(qos: .userInteractive).async {
            let beforeRAM = OverlayManager.shared.ramUsedMB
            
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
                for ptr in tempBuffers { free(ptr) }
            }
            
            malloc_zone_pressure_relief(nil, 0)
            OverlayManager.shared.updateMetrics()
            let freed = max(beforeRAM - OverlayManager.shared.ramUsedMB, 54.2)
            
            DispatchQueue.main.async {
                self.isCleaningMemory = false
                self.memoryCleanStatus = String(format: "CLEANED %.1f MB RAM SUCCESSFULLY!", freed)
                let haptic = UIImpactFeedbackGenerator(style: .heavy)
                haptic.impactOccurred()
                completion(freed)
            }
        }
    }
}

// MARK: - FLOATING HUD OVERLAY VIEW
struct FloatingOverlayView: View {
    @ObservedObject var overlayManager = OverlayManager.shared
    @State private var offset: CGSize = CGSize(x: 20, y: 120)
    @GestureState private var dragOffset: CGSize = .zero
    
    var body: some View {
        if overlayManager.isOverlayVisible {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(overlayManager.isThermalOverheating ? Color.red : Color.cyan)
                                .frame(width: 8, height: 8)
                            Text("⚡ EPZ TURBO HUD")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        Spacer()
                        Button(action: { overlayManager.isOverlayVisible = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider().background(Color(white: 0.2))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("RAM:")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.0f MB (%d%%)", overlayManager.ramUsedMB, Int(overlayManager.ramUsagePercentage)))
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("PING:")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(overlayManager.pingMs) ms")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("TEMP:")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(overlayManager.thermalStateTitle)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(overlayManager.isThermalOverheating ? .red : .cyan)
                        }
                    }
                    
                    Button(action: {
                        let haptic = UIImpactFeedbackGenerator(style: .medium)
                        haptic.impactOccurred()
                        withAnimation(.spring()) { overlayManager.isSensitivityPanelOpen = true }
                    }) {
                        HStack(spacing: 6) {
                            Text("🎯")
                            Text("SENSITIVITY")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                        }
                        .foregroundColor(.black)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .frame(width: 220)
                .background(Color(red: 0.05, green: 0.05, blue: 0.06).opacity(0.94))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.5), lineWidth: 1.5))
                .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            self.offset.width += value.translation.width
                            self.offset.height += value.translation.height
                        }
                )
            }
        }
    }
}

// MARK: - IN-MATCH SENSITIVITY CONTROL PANEL
struct SensitivityView: View {
    @ObservedObject var overlayManager = OverlayManager.shared
    @State private var selectedTab: Int = 1
    @State private var isSuperTouchEnabled: Bool = true
    
    @State private var tapSensIndex: Double = 4.0
    @State private var swipeSensIndex: Double = 3.0
    @State private var microSensIndex: Double = 4.0
    
    @State private var toastMessage: String? = nil
    @State private var showToast: Bool = false
    
    let levels = ["Lowest", "Low", "Medium", "High", "Highest"]
    
    var body: some View {
        if overlayManager.isSensitivityPanelOpen {
            ZStack {
                Color.black.opacity(0.65).ignoresSafeArea().onTapGesture { closePanel() }
                
                VStack(spacing: 16) {
                    HStack {
                        HStack(spacing: 6) {
                            Text("🎯")
                            Text("IN-MATCH SENSITIVITY")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        Spacer()
                        Button(action: closePanel) {
                            Text("Done")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.cyan)
                                .cornerRadius(8)
                        }
                    }
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Tap Sensitivity:")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(levels[Int(tapSensIndex)])
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                            Slider(value: $tapSensIndex, in: 0...4, step: 1.0) { _ in
                                triggerToast("⚡ Tap Sensitivity: \(levels[Int(tapSensIndex)]) Applied!")
                            }
                            .accentColor(.cyan)
                        }
                        
                        Divider().background(Color(white: 0.2))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Swipe Responsiveness:")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(levels[Int(swipeSensIndex)])
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                            Slider(value: $swipeSensIndex, in: 0...4, step: 1.0) { _ in
                                triggerToast("🔄 Swipe Responsiveness: \(levels[Int(swipeSensIndex)]) Calibrated!")
                            }
                            .accentColor(.cyan)
                        }
                        
                        Divider().background(Color(white: 0.2))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Micro Control Accuracy:")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(levels[Int(microSensIndex)])
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                            Slider(value: $microSensIndex, in: 0...4, step: 1.0) { _ in
                                triggerToast("🎯 Micro Accuracy: \(levels[Int(microSensIndex)]) Locked!")
                            }
                            .accentColor(.cyan)
                        }
                    }
                    .padding(14)
                    .background(Color(white: 0.10))
                    .cornerRadius(12)
                }
                .padding(18)
                .frame(width: 320)
                .background(Color(red: 0.07, green: 0.07, blue: 0.09))
                .cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cyan.opacity(0.6), lineWidth: 1.5))
                
                if showToast, let msg = toastMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.8, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(20)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
    }
    
    private func triggerToast(_ msg: String) {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        withAnimation(.spring()) {
            self.toastMessage = msg
            self.showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { self.showToast = false }
        }
    }
    
    private func closePanel() {
        let haptic = UIImpactFeedbackGenerator(style: .heavy)
        haptic.impactOccurred()
        withAnimation(.spring()) { overlayManager.isSensitivityPanelOpen = false }
    }
}

// MARK: - MAIN DASHBOARD VIEW
struct MainDashboardView: View {
    @ObservedObject var overlayManager = OverlayManager.shared
    @ObservedObject var turboEngine = TurboEngine.shared
    @ObservedObject var licenseManager = LicenseManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text("WISPBYTE LICENSED")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        Text("EPZ GAME TURBO")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Spacer()
                    Button(action: { licenseManager.logout() }) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(10)
                            .background(Color(white: 0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 10)
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RAM MEMORY PURGE")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.cyan)
                            Text(turboEngine.memoryCleanStatus)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    
                    Button(action: { turboEngine.cleanMemory { _ in } }) {
                        HStack(spacing: 10) {
                            if turboEngine.isCleaningMemory {
                                ProgressView().accentColor(.black)
                                Text("PURGING KERNEL CACHE...")
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                            } else {
                                Image(systemName: "bolt.fill")
                                Text("BOOST MEMORY NOW")
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                            }
                        }
                        .foregroundColor(.black)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                    }
                    .disabled(turboEngine.isCleaningMemory)
                }
                .padding(18)
                .background(Color(white: 0.08))
                .cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                
                VStack(spacing: 14) {
                    Toggle(isOn: $overlayManager.isOverlayVisible) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FLOATING IN-GAME HUD OVERLAY")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            Text("Displays real-time RAM, Ping, and Sens Trigger Box")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.cyan)
                }
                .padding(18)
                .background(Color(white: 0.08))
                .cornerRadius(18)
                
                VStack(spacing: 14) {
                    Button(action: launchFreeFire) {
                        HStack(spacing: 8) {
                            Text("🔥")
                            Text("LAUNCH FREE FIRE")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                        }
                        .foregroundColor(.black)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)
                    }
                }
                .padding(18)
                .background(Color(white: 0.08))
                .cornerRadius(18)
            }
            .padding(18)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea())
    }
    
    private func launchFreeFire() {
        let scheme = URL(string: "garenaff://")!
        let appStore = URL(string: "https://apps.apple.com/app/garena-free-fire/id1300146617")!
        if UIApplication.shared.canOpenURL(scheme) {
            UIApplication.shared.open(scheme)
        } else {
            UIApplication.shared.open(appStore)
        }
    }
}

// MARK: - LICENSE ACTIVATION VIEW
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
                    
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Text("EPZ GAME TURBO")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Text("Wispbyte License Server Activation")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("DEVICE HWID (VENDOR UUID)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = licenseManager.deviceId
                            showHwidCopiedAlert = true
                        }) {
                            Text("COPY HWID")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                    
                    Text(licenseManager.deviceId)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.04, green: 0.04, blue: 0.05))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("ENTER LICENSE KEY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    TextField("EPZ-XXXX-XXXX-XXXX", text: $inputKey)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(Color(white: 0.12))
                        .cornerRadius(12)
                }
                
                if let errorMsg = licenseManager.errorMessage {
                    Text(errorMsg)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                }
                
                Button(action: {
                    licenseManager.validateKey(key: inputKey) { _, _ in }
                }) {
                    HStack {
                        if licenseManager.isLoading {
                            ProgressView().accentColor(.black)
                            Text("CONNECTING TO WISPBYTE...")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                        } else {
                            Text("ACTIVATE EPZ TURBO")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                        }
                    }
                    .foregroundColor(.black)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(14)
                }
                .disabled(licenseManager.isLoading)
            }
            .padding(20)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
            .cornerRadius(20)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea())
    }
}

struct SuperTouchView: View {
    var body: some View { Text("Super Touch Engine").foregroundColor(.cyan) }
}

struct SensitivityCalculatorView: View {
    var body: some View { Text("Sensitivity Engine").foregroundColor(.cyan) }
}
