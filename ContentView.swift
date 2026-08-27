//
//  ContentView.swift
//  EPZ GAME TURBO iOS
//
//  100% Self-Contained Standalone iOS Executable Suite
//

import SwiftUI
import UIKit
import Combine
import Darwin
import MachO
import QuartzCore
import AudioToolbox

// MARK: - APP MAIN ENGINE ENTRYPOINT
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

@main
struct AppLauncher {
    static func main() {
        UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            nil,
            NSStringFromClass(AppDelegate.self)
        )
    }
}

// MARK: - ROOT CONTENT VIEW & FLOATING OVERLAY CONTAINER
struct ContentView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @ObservedObject var overlayManager = OverlayManager.shared
    @State private var selectedTab = 0
