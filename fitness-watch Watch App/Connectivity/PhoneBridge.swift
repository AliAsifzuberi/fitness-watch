//
//  PhoneBridge.swift
//  fitness-watch Watch App
//
//  Sends finished recordings to the paired iPhone, then deletes them from the Watch.
//

import Foundation
import WatchConnectivity

/// Bridge = "how the Watch talks to the iPhone."
///
/// Apple’s system for this is **WatchConnectivity** (`WCSession`).
/// Think of it like a post office between the two devices:
/// - The Watch drops off a file (“transfer”)
/// - watchOS delivers it when the phone is reachable
/// - We get a callback when delivery finishes (success or failure)
@MainActor
@Observable
final class PhoneBridge: NSObject {
    static let shared = PhoneBridge()

    private(set) var statusMessage: String = "Phone link idle"
    private(set) var isActivated = false

    private override init() {
        super.init()
        activate()
    }

    /// Must be called before sending. Safe to call more than once.
    func activate() {
        // WatchConnectivity only exists when a Watch app has a companion iPhone app.
        guard WCSession.isSupported() else {
            statusMessage = "WatchConnectivity not supported"
            return
        }

        let session = WCSession.default
        // Delegates receive events ("file delivered", "phone unreachable", etc.).
        // `self` must inherit from NSObject for this older Apple pattern.
        session.delegate = self
        session.activate()
    }

    /// Send a CSV to the iPhone, then delete the Watch copy when Apple confirms delivery.
    func sendRecording(fileURL: URL, metadata: [String: Any]) {
        guard WCSession.isSupported() else {
            statusMessage = "Cannot send — WatchConnectivity unavailable"
            return
        }

        let session = WCSession.default
        guard session.activationState == .activated else {
            statusMessage = "Phone link not ready — open iPhone app once"
            // Still queue activation; user can tap retry later.
            session.activate()
            return
        }

        // `transferFile` is the right API for CSVs:
        // - Works even if the iPhone app is in the background
        // - Queues the transfer until the phone is available
        // - Better than stuffing big data into a "message"
        session.transferFile(fileURL, metadata: metadata)
        statusMessage = "Queued transfer to iPhone…"
    }
}

// MARK: - WCSessionDelegate
//
// These methods are called by the system (not by us).
// `nonisolated` = may run off the main thread; we hop back for UI state.

extension PhoneBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                statusMessage = "Link failed: \(error.localizedDescription)"
                isActivated = false
                return
            }
            isActivated = (activationState == .activated)
            statusMessage = isActivated ? "Phone link ready" : "Phone link not active"
        }
    }

    /// Called when a file transfer finishes (success OR failure).
    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        let localURL = fileTransfer.file.fileURL

        Task { @MainActor in
            if let error {
                // Keep the file on Watch so we can retry later.
                statusMessage = "Transfer failed: \(error.localizedDescription)"
                return
            }

            // Delivery confirmed → delete Watch copy to free storage.
            do {
                try FileManager.default.removeItem(at: localURL)
                statusMessage = "Sent to iPhone — Watch copy deleted"
            } catch {
                statusMessage = "Sent, but delete failed: \(error.localizedDescription)"
            }
        }
    }

    // Required on iOS; on watchOS some session methods differ.
    // Empty stubs keep the compiler happy if signatures require them.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {}
}
