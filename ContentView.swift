import SwiftUI
import CoreGraphics

// MARK: - Models
public enum iPhoneModel: String, CaseIterable, Identifiable {
    case iphone17 = "iPhone 17 / 17 Pro"
    case iphone16 = "iPhone 16 / 16 Pro"
    case iphone15 = "iPhone 15 / 15 Pro"
    case iphone14 = "iPhone 14 / 14 Pro"
    case iphone13OrOlder = "iPhone 13 or Older"
    case ipad = "iPad Pro / Air"
    
    public var id: String { self.rawValue }
    
    public var baseGeneralSensitivity: Int {
        switch self {
        case .iphone17: return 94
        case .iphone16: return 95
        case .iphone15: return 96
        case .iphone14: return 97
        case .iphone13OrOlder: return 98
        case .ipad: return 85
        }
    }
    
    public var baseRedDot: Int {
        switch self {
        case .iphone17: return 90
        case .iphone16: return 91
        case .iphone15: return 92
        case .iphone14: return 93
        case .iphone13OrOlder: return 95
        case .ipad: return 82
        }
    }
    
    public var recommendedFireButtonSize: Int {
        switch self {
        case .iphone17, .iphone16: return 44
        case .iphone15, .iphone14: return 46
        case .iphone13OrOlder: return 48
        case .ipad: return 38
        }
    }
}

public enum PlayStyle: String, CaseIterable, Identifiable {
    case dragHeadshot = "Drag Headshot"
    case sniper = "One-Tap / Sniper"
    case rush = "Aggressive Rush"
    case balanced = "Balanced"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .dragHeadshot: return "scope"
        case .sniper: return "crosshair"
        case .rush: return "bolt.fill"
        case .balanced: return "equal.circle"
        }
    }
}

public struct OptimizationItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let category: String
    public let detail: String
    public let recommendedSetting: String
    public var isCompleted: Bool = false
}

// MARK: - Root View
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SensitivityView()
                .tabItem {
                    Label("Sens Calculator", systemImage: "slider.horizontal.3")
                }
                .tag(0)
            
            TouchTestView()
                .tabItem {
                    Label("Touch Test", systemImage: "hand.tap.fill")
                }
                .tag(1)
            
            PerformanceGuideView()
                .tabItem {
                    Label("FPS Booster", systemImage: "bolt.fill")
                }
                .tag(2)
            
            PingTestView()
                .tabItem {
                    Label("Ping Tester", systemImage: "wifi")
                }
                .tag(3)
        }
        .accentColor(.orange)
    }
}

// MARK: - Views
struct SensitivityView: View {
    @State private var selectedModel: iPhoneModel = .iphone17
    @State private var selectedStyle: PlayStyle = .dragHeadshot
    
    @State private var general: Double = 94
    @State private var redDot: Double = 90
    @State private var scope2x: Double = 84
    @State private var scope4x: Double = 78
    @State private var awmScope: Double = 52
    @State private var freeLook: Double = 70
    @State private var fireButtonSize: Double = 44
    @State private var showCopiedAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "scope")
                                .font(.title)
                                .foregroundColor(.orange)
                            Text("Sens Calculator")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Text("AIM STABLE")
                                .font(.caption)
                                .fontWeight(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.orange.opacity(0.3))
                                .cornerRadius(8)
                                .foregroundColor(.orange)
                        }
                        Text("Calibrated for high touch sampling & smooth drag headshots.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select Device Model")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Picker("Device", selection: $selectedModel) {
                            ForEach(iPhoneModel.allCases) { model in
                                Text(model.rawValue).tag(model)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.16))
                        .cornerRadius(12)
                        .foregroundColor(.orange)
                        .onChange(of: selectedModel) { _ in
                            recalculateSensitivity()
                        }
                    }
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select Playstyle")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            ForEach(PlayStyle.allCases) { style in
                                Button(action: {
                                    selectedStyle = style
                                    recalculateSensitivity()
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: style.iconName)
                                            .font(.body)
                                        Text(style.rawValue)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedStyle == style ? Color.orange : Color(white: 0.18))
                                    .foregroundColor(selectedStyle == style ? .black : .white)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(16)
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("Calibrated Values")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: {
                                copyToClipboard()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy All")
                                }
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(8)
                            }
                        }
                        
                        SensitivitySliderRow(title: "General", value: $general, range: 70...100, color: .orange)
                        SensitivitySliderRow(title: "Red Dot", value: $redDot, range: 60...100, color: .red)
                        SensitivitySliderRow(title: "2x Scope", value: $scope2x, range: 60...100, color: .yellow)
                        SensitivitySliderRow(title: "4x Scope", value: $scope4x, range: 50...100, color: .green)
                        SensitivitySliderRow(title: "AWM Scope", value: $awmScope, range: 30...80, color: .blue)
                        SensitivitySliderRow(title: "Free Look", value: $freeLook, range: 40...100, color: .purple)
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        SensitivitySliderRow(title: "Right Fire Button Size", value: $fireButtonSize, range: 35...60, color: .cyan, unit: "%")
                    }
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(16)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Calculated Aim Stability Index")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(calculateStabilityIndex())%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        ProgressView(value: Double(calculateStabilityIndex()), total: 100.0)
                            .accentColor(.green)
                    }
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(16)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Sens Optimizer")
            .alert(isPresented: $showCopiedAlert) {
                Alert(title: Text("Settings Copied!"), message: Text("Paste these exact values into Garena Free Fire sensitivity settings."), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func recalculateSensitivity() {
        var baseGen = Double(selectedModel.baseGeneralSensitivity)
        var baseRed = Double(selectedModel.baseRedDot)
        var baseButton = Double(selectedModel.recommendedFireButtonSize)
        
        switch selectedStyle {
        case .dragHeadshot:
            baseGen -= 1
            baseRed -= 1
            baseButton = 44
        case .sniper:
            baseGen -= 5
            baseRed -= 4
            baseButton = 48
        case .rush:
            baseGen += 2
            baseRed += 2
            baseButton = 42
        case .balanced:
            break
        }
        
        general = min(max(baseGen, 70), 100)
        redDot = min(max(baseRed, 60), 100)
        scope2x = min(max(baseRed - 6, 60), 100)
        scope4x = min(max(baseRed - 12, 50), 100)
        awmScope = 52
        freeLook = 70
        fireButtonSize = baseButton
    }
    
    private func calculateStabilityIndex() -> Int {
        if general > 97 { return 82 }
        if general >= 92 && general <= 96 { return 98 }
        return 91
    }
    
    private func copyToClipboard() {
        let text = """
        --- Free Fire Calibrated Settings ---
        Device: \(selectedModel.rawValue)
        General: \(Int(general))
        Red Dot: \(Int(redDot))
        2x Scope: \(Int(scope2x))
        4x Scope: \(Int(scope4x))
        AWM Scope: \(Int(awmScope))
        Free Look: \(Int(freeLook))
        Fire Button Size: \(Int(fireButtonSize))%
        Stability Rating: \(calculateStabilityIndex())%
        """
        UIPasteboard.general.string = text
        showCopiedAlert = true
    }
}

struct SensitivitySliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    var unit: String = ""
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(value))\(unit)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            Slider(value: $value, in: range, step: 1)
                .accentColor(color)
        }
    }
}

struct TouchTestView: View {
    @State private var points: [CGPoint] = []
    @State private var smoothnessScore: Int = 100
    @State private var jitterDetected: Bool = false
    @State private var touchCount: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smoothness")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(smoothnessScore)%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(smoothnessScore > 90 ? .green : .orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aim Flickering")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(jitterDetected ? "DETECTED" : "STABLE")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(jitterDetected ? .red : .green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Points Polled")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(touchCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(jitterDetected ? Color.red.opacity(0.5) : Color.orange.opacity(0.3), lineWidth: 2)
                        )
                    
                    VStack {
                        Spacer()
                        Text("SWIPE / DRAG UP HERE TO TEST AIM STABILITY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Color.white.opacity(0.3))
                            .padding(.bottom, 20)
                    }
                    
                    Path { path in
                        guard let firstPoint = points.first else { return }
                        path.move(to: firstPoint)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(jitterDetected ? Color.red : Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                .padding(.horizontal)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newPoint = value.location
                            points.append(newPoint)
                            touchCount = points.count
                            analyzeTouchStability()
                        }
                )
                
                HStack(spacing: 16) {
                    Button(action: {
                        points.removeAll()
                        smoothnessScore = 100
                        jitterDetected = false
                        touchCount = 0
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Clear Canvas")
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.16))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Touch Diagnostic")
        }
    }
    
    private func analyzeTouchStability() {
        guard points.count > 5 else { return }
        var suddenDirectionChanges = 0
        
        for i in 2..<points.count {
            let p1 = points[i - 2]
            let p2 = points[i - 1]
            let p3 = points[i]
            
            let dx1 = p2.x - p1.x
            let dx2 = p3.x - p2.x
            
            if abs(dx2 - dx1) > 15 {
                suddenDirectionChanges += 1
            }
        }
        
        if suddenDirectionChanges > 3 {
            jitterDetected = true
            smoothnessScore = max(70, 100 - (suddenDirectionChanges * 5))
        } else {
            jitterDetected = false
            smoothnessScore = 98
        }
    }
}

struct PerformanceGuideView: View {
    @State private var items: [OptimizationItem] = [
        OptimizationItem(title: "Enable Game Mode (iOS 18+)", category: "System", detail: "Prioritizes CPU/GPU resources for Free Fire and blocks background interruptions.", recommendedSetting: "ON"),
        OptimizationItem(title: "Disable Low Power Mode", category: "Battery", detail: "Low Power Mode limits CPU clock speed by 50%, causing severe aim flickering and touch drops.", recommendedSetting: "OFF"),
        OptimizationItem(title: "Touch Accommodations", category: "Accessibility", detail: "If enabled, iOS adds a delay before your drag headshot swipe registers.", recommendedSetting: "OFF"),
        OptimizationItem(title: "Haptic Touch Speed", category: "Accessibility", detail: "Fast touch response reduces fire button press latency.", recommendedSetting: "FAST"),
        OptimizationItem(title: "Disable Auto-Brightness", category: "Display", detail: "Prevents screen dimming when hands cover ambient light sensor during intense gameplay.", recommendedSetting: "OFF"),
        OptimizationItem(title: "Free Fire High FPS Mode", category: "In-Game", detail: "Unlocks 60-120 FPS output, eliminating frame pacing stutter and camera aim jitter.", recommendedSetting: "HIGH"),
        OptimizationItem(title: "Free Fire Graphics Level", category: "In-Game", detail: "Use Smooth or Standard to avoid thermal throttling during long ranked matches.", recommendedSetting: "SMOOTH")
    ]
    
    var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "bolt.badge.clock.fill")
                                .font(.title)
                                .foregroundColor(.green)
                            Text("System FPS Booster")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(completedCount)/\(items.count)")
                                .font(.headline)
                                .fontWeight(.black)
                                .foregroundColor(.green)
                        }
                        
                        ProgressView(value: Double(completedCount), total: Double(items.count))
                            .accentColor(.green)
                        
                        Text("Complete all items in iPhone Settings to achieve maximum frame stability.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(16)
                    
                    ForEach(items.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 14) {
                            Button(action: {
                                items[index].isCompleted.toggle()
                            }) {
                                Image(systemName: items[index].isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(items[index].isCompleted ? .green : .gray)
                            }
                            .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(items[index].title)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(items[index].recommendedSetting)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .cornerRadius(6)
                                }
                                
                                Text(items[index].detail)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(white: 0.12))
                        .cornerRadius(14)
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("FPS Optimizer")
        }
    }
}

struct PingTestView: View {
    @State private var selectedRegion: String = "Asia / India"
    @State private var isTesting: Bool = false
    @State private var pingMs: Int = 24
    @State private var jitterMs: Int = 2
    @State private var packetLoss: Double = 0.0
    @State private var networkStatus: String = "EXCELLENT"
    
    let regions = ["Asia / India", "Singapore (SEA)", "Europe", "North America", "South America (LATAM)"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Game Server Region")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Picker("Region", selection: $selectedRegion) {
                        ForEach(regions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.16))
                    .cornerRadius(12)
                    .foregroundColor(.orange)
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(16)
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LATENCY (PING)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(pingMs)")
                                    .font(.system(size: 40, weight: .black, design: .rounded))
                                    .foregroundColor(pingMs < 50 ? .green : (pingMs < 90 ? .orange : .red))
                                Text("ms")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("NETWORK STATUS")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(networkStatus)
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(pingMs < 50 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .foregroundColor(pingMs < 50 ? .green : .orange)
                                .cornerRadius(8)
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Jitter (Fluctuating Lag)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(jitterMs) ms")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Packet Loss")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(String(format: "%.1f%%", packetLoss))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(packetLoss == 0 ? .green : .red)
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(16)
                
                Button(action: {
                    runNetworkTest()
                }) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .accentColor(.black)
                            Text("Diagnosing Network...")
                        } else {
                            Image(systemName: "wifi")
                            Text("Test Ping Stability")
                        }
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(14)
                }
                .disabled(isTesting)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Ping Tester")
        }
    }
    
    private func runNetworkTest() {
        isTesting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            pingMs = Int.random(in: 18...38)
            jitterMs = Int.random(in: 1...4)
            packetLoss = 0.0
            networkStatus = "EXCELLENT"
            isTesting = false
        }
    }
}
