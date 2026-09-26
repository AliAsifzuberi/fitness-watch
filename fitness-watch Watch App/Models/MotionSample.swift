//
//  MotionSample.swift
//  fitness-watch Watch App
//
//  One row of sensor data — matches our Phase 1 CSV schema.
//

import Foundation

/// A `struct` is a lightweight value type (copied when passed around).
/// Perfect for thousands of sensor rows.
struct MotionSample {
    let timestampMs: Int
    let ax: Double
    let ay: Double
    let az: Double
    let gx: Double
    let gy: Double
    let gz: Double
    let gravX: Double
    let gravY: Double
    let gravZ: Double

    /// Turns one sample into a CSV line.
    /// `String(format:)` is like printf — good for fixed decimal places.
    var csvLine: String {
        String(
            format: "%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f",
            timestampMs,
            ax, ay, az,
            gx, gy, gz,
            gravX, gravY, gravZ
        )
    }

    static let csvHeader =
        "timestamp_ms,ax,ay,az,gx,gy,gz,grav_x,grav_y,grav_z,label,session_id,subject_id,wrist,weight_kg,true_reps"
}
