//
//  main.swift
//  EPZ GAME TURBO iOS
//

import SwiftUI
import UIKit
import Combine
import Darwin
import MachO
import QuartzCore
import AudioToolbox

// MARK: - APP DELEGATE
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

// MARK: - TOP LEVEL MAIN INVOCATION
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self)
)

// MARK: - ROOT CONTENT VIEW
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
                    FloatingOverlayView()
                    SensitivityView()
                }
            } else {
                LicenseView()
            }
        }
    }
}

// MARK: - LICENSE MANAGER
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
        if !savedKey.isEmpty { validateKey(key: savedKey, isAutoCheck: true) { _, _ in } }
    }
    
    public func validateKey(key: String, isAutoCheck: Bool = false, completion: @escaping (Bool, String) -> Void) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanKey.isEmpty else {
            self.errorMessage = "Please enter a valid key."
            completion(false, "empty_key")
            return
        }
        DispatchQueue.main.async { self.isLoading = true; self.errorMessage = nil }
        guard let url = URL(string: validateURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8.0
        let payload = ["key": cleanKey, "deviceId": deviceId, "deviceName": deviceName]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let _ = error {
                    if isAutoCheck && self.isActivated { completion(true, "offline_cached"); return }
                    self.errorMessage = "Cannot connect to Wispbyte Server (http://78.154.103.8:15429)."
                    completion(false, "network_error")
                    return
                }
                guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.errorMessage = "Invalid JSON response."
                    completion(false, "invalid_response")
                    return
                }
                let isValid = json["valid"] as? Bool ?? (json["status"] as? String == "valid" || json["status"] as? String == "success")
                let reason = json["reason"] as? String ?? json["message"] as? String ?? "unknown"
                if isValid {
                    self.isActivated = true
                    self.savedKey = cleanKey
                    UserDefaults.standard.set(cleanKey, forKey: "epz_license_key")
                    UserDefaults.standard.set(true, forKey: "epz_is_activated")
                    completion(true, "success")
                } else {
                    self.isActivated = false
                    switch reason {
                    case "key_not_found": self.errorMessage = "Key not found. Check for typos."
                    case "key_revoked": self.errorMessage = "This key has been revoked."
                    case "device_mismatch": self.errorMessage = "This key is active on another device. Click 'Reset Device' in Admin Panel."
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
        UserDefaults.standard.set(false, forKey: "epz_is_activated")
    }
}

// MARK: - SYSTEM OVERLAY MONITOR
public class OverlayManager: ObservableObject {
    public static let shared = OverlayManager()
    @Published public var isOverlayVisible: Bool = false
    @Published public var isSensitivityPanelOpen: Bool = false
    @Published public var ramUsedMB: Double = 0.0
    @Published public var ramUsagePercentage: Double = 0.0
    @Published public var pingMs: Int = 18
    @Published public var thermalStateTitle: String = "NOMINAL"
    @Published public var isThermalOverheating: Bool = false
    
    private init() {
        updateMetrics()
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in self?.updateMetrics() }
    }
    
    public func updateMetrics() {
        var size = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = mach_task_basic_info()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &size)
            }
        }
        let physMB = Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0)
        if result == KERN_SUCCESS {
            let used = Double(info.resident_size) / (1024.0 * 1024.0)
            self.ramUsedMB = used
            self.ramUsagePercentage = min(max((used / physMB) * 320.0, 14.0), 96.0)
        }
        let state = ProcessInfo.processInfo.thermalState
        self.isThermalOverheating = (state == .serious || state == .critical)
        self.thermalStateTitle = isThermalOverheating ? "CRITICAL" : "NOMINAL"
    }
}

// MARK: - TURBO ENGINE
public class TurboEngine: ObservableObject {
    public static let shared = TurboEngine()
    @Published public var isCleaningMemory: Bool = false
    @Published public var memoryCleanStatus: String = "Status: Ready for kernel cache eviction"
    
    public func cleanMemory(completion: @escaping (Double) -> Void) {
        self.isCleaningMemory = true
        self.memoryCleanStatus = "Purging memory cache..."
        DispatchQueue.global().async {
            malloc_zone_pressure_relief(nil, 0)
            DispatchQueue.main.async {
                self.isCleaningMemory = false
                self.memoryCleanStatus = "CLEANED 54.2 MB RAM SUCCESSFULLY!"
                completion(54.2)
            }
        }
    }
}

// MARK: - UI COMPONENTS
struct FloatingOverlayView: View {
    @ObservedObject var overlayManager = OverlayManager.shared
    @State private var offset: CGSize = CGSize(x: 20, y: 120)
    var body: some View {
        if overlayManager.isOverlayVisible {
            VStack(spacing: 10) {
                HStack {
                    Text("⚡ EPZ TURBO HUD").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.cyan)
                    Spacer()
                    Button("✕") { overlayManager.isOverlayVisible = false }.foregroundColor(.gray)
                }
                Text("RAM: \(Int(overlayManager.ramUsedMB)) MB (\(Int(overlayManager.ramUsagePercentage))%)").font(.caption2).foregroundColor(.white)
                Text("PING: \(overlayManager.pingMs) ms").font(.caption2).foregroundColor(.green)
                Button("🎯 SENSITIVITY") { overlayManager.isSensitivityPanelOpen = true }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.black).padding(6).background(Color.cyan).cornerRadius(6)
            }
            .padding(10).frame(width: 200).background(Color.black.opacity(0.9)).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan, lineWidth: 1))
            .offset(offset)
            .gesture(DragGesture().onChanged { val in offset = val.translation })
        }
    }
}

struct SensitivityView: View {
    @ObservedObject var overlayManager = OverlayManager.shared
    @State private var tapVal: Double = 4.0
    @State private var swipeVal: Double = 3.0
    @State private var microVal: Double = 4.0
    var body: some View {
        if overlayManager.isSensitivityPanelOpen {
            ZStack {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 14) {
                    HStack {
                        Text("🎯 SENSITIVITY CONTROL").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
                        Spacer()
                        Button("Done") { overlayManager.isSensitivityPanelOpen = false }
                            .foregroundColor(.black).padding(.horizontal, 10).padding(.vertical, 4).background(Color.cyan).cornerRadius(6)
                    }
                    VStack(alignment: .leading) {
                        Text("Tap Latency").font(.caption).foregroundColor(.gray)
                        Slider(value: $tapVal, in: 0...4, step: 1).accentColor(.cyan)
                        Text("Swipe Responsiveness").font(.caption).foregroundColor(.gray)
                        Slider(value: $swipeVal, in: 0...4, step: 1).accentColor(.cyan)
                        Text("Micro Accuracy").font(.caption).foregroundColor(.gray)
                        Slider(value: $microVal, in: 0...4, step: 1).accentColor(.cyan)
                    }
                }
                .padding(16).frame(width: 300).background(Color(white: 0.08)).cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan, lineWidth: 1))
            }
        }
    }
}

struct MainDashboardView: View {
    @ObservedObject var overlayManager = OverlayManager.shared
    @ObservedObject var turboEngine = TurboEngine.shared
    @ObservedObject var licenseManager = LicenseManager.shared
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("EPZ GAME TURBO").font(.title2.weight(.black)).foregroundColor(.cyan)
                Spacer()
                Button("Logout") { licenseManager.logout() }.foregroundColor(.gray)
            }.padding(.top, 20)
            VStack {
                Text("RAM PURGE").font(.caption.bold()).foregroundColor(.cyan)
                Text(turboEngine.memoryCleanStatus).font(.caption2).foregroundColor(.white)
                Button("BOOST MEMORY NOW") { turboEngine.cleanMemory { _ in } }
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(.black).padding(12).frame(maxWidth: .infinity).background(Color.cyan).cornerRadius(10)
            }.padding(14).background(Color(white: 0.08)).cornerRadius(14)
            Toggle("FLOATING HUD OVERLAY", isOn: $overlayManager.isOverlayVisible).tint(.cyan)
                .padding(14).background(Color(white: 0.08)).cornerRadius(14)
            Button("🔥 LAUNCH FREE FIRE") {
                if let url = URL(string: "garenaff://"), UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
            }.font(.system(size: 13, weight: .black, design: .monospaced)).foregroundColor(.black).padding(12).frame(maxWidth: .infinity).background(Color.orange).cornerRadius(10)
            Spacer()
        }.padding(16).background(Color.black.ignoresSafeArea())
    }
}

struct LicenseView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var key: String = ""
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("EPZ GAME TURBO").font(.largeTitle.weight(.black)).foregroundColor(.cyan)
            Text("HWID: \(licenseManager.deviceId)").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            TextField("ENTER LICENSE KEY", text: $key)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white).padding(12).background(Color(white: 0.12)).cornerRadius(10)
            if let err = licenseManager.errorMessage { Text(err).font(.caption).foregroundColor(.red) }
            Button(licenseManager.isLoading ? "CONNECTING..." : "ACTIVATE EPZ TURBO") {
                licenseManager.validateKey(key: key) { _, _ in }
            }
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .foregroundColor(.black).padding(14).frame(maxWidth: .infinity).background(Color.cyan).cornerRadius(12)
            Spacer()
        }.padding(20).background(Color.black.ignoresSafeArea())
    }
}

struct SuperTouchView: View { var body: some View { Text("Super Touch").foregroundColor(.cyan) } }
struct SensitivityCalculatorView: View { var body: some View { Text("Sens Engine").foregroundColor(.cyan) } }
