//
//  ContentView.swift
//  FreeFireCompanion
//
//  Root Navigation & TabBar View
//

import SwiftUI

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
