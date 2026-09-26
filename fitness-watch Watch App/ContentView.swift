//
//  ContentView.swift
//  fitness-watch Watch App
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // Phase 1: data collection is the whole app for now.
        // Later we'll add a tab or menu for live workouts.
        DataCollectionView()
    }
}

#Preview {
    ContentView()
}
