//
//  fitness_watchApp.swift
//  fitness-watch (iPhone)
//

import SwiftUI

@main
struct fitness_watchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Activate WatchConnectivity as soon as the app launches.
                .onAppear { WatchBridge.shared.activate() }
        }
    }
}
