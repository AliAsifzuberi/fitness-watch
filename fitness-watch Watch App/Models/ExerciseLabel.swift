//
//  ExerciseLabel.swift
//  fitness-watch Watch App
//
//  The fixed set of labels we record in Phase 1.
//

import Foundation

/// An `enum` is a type with a fixed list of cases.
/// `String` raw values let us write clean CSV labels like "bench_press".
enum ExerciseLabel: String, CaseIterable, Identifiable {
    case benchPress = "bench_press"
    case shoulderPressMachine = "shoulder_press_machine"
    case dumbbellCurl = "dumbbell_curl"
    case latPulldown = "lat_pulldown"
    case tricepPushdown = "tricep_pushdown"
    case other = "other"

    /// `Identifiable` is required by SwiftUI lists/ForEach so each row has a stable id.
    var id: String { rawValue }

    /// Short text for big watch buttons.
    var displayName: String {
        switch self {
        case .benchPress: return "Bench"
        case .shoulderPressMachine: return "Shoulder Press"
        case .dumbbellCurl: return "DB Curl"
        case .latPulldown: return "Lat Pulldown"
        case .tricepPushdown: return "Tricep Pushdown"
        case .other: return "Other / Rest"
        }
    }
}
