//
//  CSVWriter.swift
//  fitness-watch Watch App
//
//  Builds a CSV file in the app's Documents folder.
//

import Foundation

enum CSVWriter {
    /// Staging folder on the Watch. Files should be short-lived:
    /// we transfer to the iPhone, then delete (see PhoneBridge).
    static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("RecordingsStaging", isDirectory: true)
        // `try?` means: attempt, ignore error if folder already exists.
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func writeRecording(
        samples: [MotionSample],
        label: ExerciseLabel,
        sessionID: UUID,
        subjectID: String,
        wrist: String,
        weightKg: Double?,
        trueReps: Int
    ) throws -> URL {
        let fileName = "\(sessionID.uuidString)_\(label.rawValue).csv"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)

        let weightText: String
        if let weightKg {
            weightText = String(format: "%.2f", weightKg)
        } else {
            weightText = ""
        }

        // Metadata columns repeat on every row so training tools can group by session easily.
        var lines: [String] = [MotionSample.csvHeader]
        lines.reserveCapacity(samples.count + 1)

        for sample in samples {
            let row = [
                sample.csvLine,
                label.rawValue,
                sessionID.uuidString,
                subjectID,
                wrist,
                weightText,
                String(trueReps)
            ].joined(separator: ",")
            lines.append(row)
        }

        let csv = lines.joined(separator: "\n") + "\n"
        // Atomic write = all-or-nothing (safer if the app is killed mid-save).
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
