import AVFoundation
import Combine
import Foundation

/// KVO wrapper around `AVPlayer.timeControlStatus`, the authoritative
/// "what is the player doing right now" signal maintained by AVFoundation.
///
/// Three values:
/// - `.paused` — explicit pause (user, app, navigation away, etc.)
/// - `.waitingToPlayAtSpecifiedRate` — buffering / loading / waiting on
///   network. This is what a "loading indicator" should track.
/// - `.playing` — actively playing back at the requested rate.
///
/// Observing this directly via KVO is the canonical AppKit/UIKit /
/// AVFoundation pattern (recommended on Apple's docs, Stack Overflow's
/// canonical answer #79174744, multiple Apple sample apps). It survives
/// state-machine quirks, navigation re-mounts, scrub/seek, replay, app
/// background/foreground — anything the underlying AVPlayer exposes,
/// timeControlStatus reflects.
///
/// The KSPlayer high-level `KSPlayerState` enum used by the rest of this
/// app sometimes does NOT re-fire onStateChanged across navigation
/// (state didn't *change* even though the view was rebuilt), which is
/// why deriving the loading flag from it produced the "HUD stuck on
/// after popping back" bug. timeControlStatus does not have this issue.
@MainActor
final class AVPlayerStatusObserver: ObservableObject {
    @Published private(set) var timeControlStatus: AVPlayer.TimeControlStatus = .paused

    private var observation: NSKeyValueObservation?
    private weak var observed: AVPlayer?

    /// Bind this observer to an AVPlayer (or unbind by passing nil).
    /// Idempotent — calling repeatedly with the same player is a no-op.
    /// The current `timeControlStatus` is published synchronously so the
    /// view never observes a stale `.paused` after rebinding to a new
    /// already-playing player.
    func observe(_ player: AVPlayer?) {
        if observed === player { return }
        observation?.invalidate()
        observation = nil
        observed = player
        guard let player else {
            timeControlStatus = .paused
            return
        }
        timeControlStatus = player.timeControlStatus
        observation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            // KVO callbacks may not be on the main thread; hop back so the
            // @Published mutation triggers SwiftUI updates safely.
            Task { @MainActor [weak self] in
                self?.timeControlStatus = p.timeControlStatus
            }
        }
    }

    deinit {
        observation?.invalidate()
    }
}
