import SwiftUI
import UIKit
import Combine
import Darwin
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
