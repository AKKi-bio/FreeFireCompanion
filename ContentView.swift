//
//  ContentView.swift
//  EPZ GAME TURBO iOS
//
//  100% Self-Contained Standalone iOS Executable Suite
//

import SwiftUI
import UIKit
import Combine
import MachO
import QuartzCore
import AudioToolbox

// MARK: - APP MAIN ENGINE ENTRYPOINT
@main
struct EPZGameTurboApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - ROOT CONTENT VIEW & FLOATING OVERLAY CONTAINER
struct ContentView: View {
    @ObservedObject var licenseManager = LicenseManager.shared
    @ObservedObject var overlayManager = OverlayManager.shared
    @State private var selectedTab = 0
