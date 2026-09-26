//
//  fitness_watchApp.swift
//  fitness-watch Watch App
//

import SwiftUI

@main
struct fitness_watch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Activate WatchConnectivity as soon as the app launches.
                .onAppear { PhoneBridge.shared.activate() }
        }
    }
}
