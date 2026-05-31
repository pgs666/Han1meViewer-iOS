import AVFoundation
import Combine
import Foundation

/// Aggregates AVFoundation's authoritative "is the player ready to show
/// frames" signals into a single @Published `isWaitingForPlayback` Bool.
///
/// True whenever any of these holds:
/// - No `AVPlayerItem` is attached yet (player just created, URL not yet
///   producing an item)
/// - The item's `status` is `.unknown` (asset metadata still loading,
///   duration not yet known — the user-visible "controls visible but
///   total time stuck at 00:01 and frame is black" phase)
/// - `timeControlStatus == .waitingToPlayAtSpecifiedRate` (AVPlayer is
///   trying to play but is stalled on network — classic mid-playback
///   rebuffer)
///
/// False once the asset is `.readyToPlay` AND the player is either
/// `.paused` (user-explicit) or `.playing`. Both are "settled" states
/// where frames are available; we don't show a loading indicator over
/// either.
///
/// Why not derive this from KSPlayer's high-level state machine: that
/// enum is a derivative summary that doesn't always re-fire across
/// view rebuilds, which is what produced the original "HUD stuck after
/// popping back" bug. The AVPlayer / AVPlayerItem KVO channels are
/// authoritative — Apple maintains them across every navigation, scrub,
/// reset, and replay scenario.
@MainActor
final class AVPlayerStatusObserver: ObservableObject {
    @Published private(set) var isWaitingForPlayback: Bool = true

    private var timeControlObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private weak var observed: AVPlayer?

    /// Bind this observer to an AVPlayer (or unbind by passing nil).
    /// Idempotent — calling repeatedly with the same player is a no-op.
    func observe(_ player: AVPlayer?) {
        if observed === player { return }
        invalidateAll()
        observed = player

        guard let player else {
            isWaitingForPlayback = true
            return
        }

        // Track timeControlStatus changes (.playing / .paused /
        // .waitingToPlayAtSpecifiedRate).
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.recompute() }
        }
        // Track currentItem changes (URL swap → new item) so we re-bind
        // the per-item status observer to the right object.
        currentItemObservation = player.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.attachItemStatusObservation()
                self?.recompute()
            }
        }
        attachItemStatusObservation()
        recompute()
    }

    private func attachItemStatusObservation() {
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        guard let item = observed?.currentItem else { return }
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.recompute() }
        }
    }

    private func recompute() {
        guard let player = observed else {
            isWaitingForPlayback = true
            return
        }
        let item = player.currentItem
        let itemStatus = item?.status ?? .unknown
        let waiting = item == nil
            || itemStatus == .unknown
            || player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        if waiting != isWaitingForPlayback {
            isWaitingForPlayback = waiting
        }
    }

    private func invalidateAll() {
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        currentItemObservation?.invalidate()
        currentItemObservation = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
    }

    deinit {
        timeControlObservation?.invalidate()
        currentItemObservation?.invalidate()
        itemStatusObservation?.invalidate()
    }
}
