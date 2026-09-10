import AVFoundation
import Combine
import Foundation
import KSPlayer

enum KSPlayerPresentationPhase: Equatable {
    case preparing
    case ready
    case buffering
    case failed(String)
}

/// Combines KSPlayer's engine-independent state with AVFoundation's detailed
/// item signals. KSPlayer remains the fallback when playback switches to the
/// FFmpeg engine; AVPlayer KVO supplies precise waiting and buffered-range data
/// whenever the default engine is active.
@MainActor
final class AVPlayerStatusObserver: ObservableObject {
    @Published private(set) var phase: KSPlayerPresentationPhase = .preparing
    @Published private(set) var isWaitingForPlayback = true
    @Published private(set) var bufferedFraction = 0.0

    private var ksState: KSPlayerState = .initialized
    private var playbackRequested = true
    private var itemStatus: AVPlayerItem.Status = .unknown
    private var currentTime: TimeInterval = 0
    private var totalTime: TimeInterval = 0
    private var loadedRanges: [CMTimeRange] = []

    private var timeControlObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var loadedRangesObservation: NSKeyValueObservation?
    private weak var observed: AVPlayer?

    func resetForNewMedia() {
        ksState = .initialized
        itemStatus = .unknown
        currentTime = 0
        totalTime = 0
        loadedRanges = []
        bufferedFraction = 0
        setPhase(.preparing)
    }

    func handleKSPlayerState(_ state: KSPlayerState) {
        ksState = state
        if state == .paused || state == .playedToTheEnd {
            playbackRequested = false
        } else if state == .buffering || state == .bufferFinished {
            playbackRequested = true
        }
        recomputePhase()
    }

    func setPlaybackRequested(_ requested: Bool) {
        playbackRequested = requested
        recomputePhase()
    }

    func reportFailure(_ error: Error) {
        setPhase(.failed(error.localizedDescription))
    }

    func clearFailure() {
        resetForNewMedia()
    }

    /// Binds to the public AVQueuePlayer exposed by KSAVPlayer. Passing nil is
    /// valid for KSMEPlayer; in that case KSPlayer state still drives the HUD.
    func observe(_ player: AVPlayer?) {
        if observed === player { return }
        invalidateAVObservations()
        observed = player

        guard let player else {
            itemStatus = .unknown
            loadedRanges = []
            recomputePhase()
            return
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.recomputePhase() }
        }
        currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.attachItemObservations()
                self?.recomputePhase()
            }
        }
        attachItemObservations()
        recomputePhase()
    }

    func updateProgress(
        current: TimeInterval,
        total: TimeInterval,
        fallbackBufferedUntil: TimeInterval
    ) {
        currentTime = current
        totalTime = total
        recomputeBufferedFraction(fallbackBufferedUntil: fallbackBufferedUntil)
    }

    private func attachItemObservations() {
        itemStatusObservation?.invalidate()
        loadedRangesObservation?.invalidate()
        itemStatusObservation = nil
        loadedRangesObservation = nil

        guard let item = observed?.currentItem else {
            itemStatus = .unknown
            loadedRanges = []
            bufferedFraction = 0
            return
        }

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                self?.itemStatus = item.status
                if item.status == .failed, let error = item.error {
                    self?.reportFailure(error)
                } else {
                    self?.recomputePhase()
                }
            }
        }
        loadedRangesObservation = item.observe(\.loadedTimeRanges, options: [.initial, .new]) { [weak self] item, _ in
            let ranges = item.loadedTimeRanges.map(\.timeRangeValue)
            Task { @MainActor [weak self] in
                self?.loadedRanges = ranges
                self?.recomputeBufferedFraction(fallbackBufferedUntil: 0)
            }
        }
    }

    private func recomputePhase() {
        if case .failed = phase { return }

        switch ksState {
        case .error:
            setPhase(.failed(String(localized: "播放失败，请重试。")))
            return
        case .initialized, .preparing, .readyToPlay:
            setPhase(playbackRequested ? .preparing : .ready)
            return
        case .buffering:
            setPhase(.buffering)
            return
        case .bufferFinished, .paused, .playedToTheEnd:
            break
        }

        if itemStatus == .failed {
            setPhase(.failed(String(localized: "播放失败，请重试。")))
        } else if observed?.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            setPhase(itemStatus == .unknown ? .preparing : .buffering)
        } else {
            setPhase(.ready)
        }
    }

    private func recomputeBufferedFraction(fallbackBufferedUntil: TimeInterval) {
        guard totalTime.isFinite, totalTime > 0 else {
            bufferedFraction = 0
            return
        }

        let bufferedUntil: TimeInterval
        if let containingRange = loadedRanges.first(where: {
            let start = $0.start.seconds
            let end = $0.end.seconds
            return start.isFinite && end.isFinite && currentTime >= start && currentTime <= end
        }) {
            bufferedUntil = containingRange.end.seconds
        } else {
            bufferedUntil = max(
                fallbackBufferedUntil,
                loadedRanges.map(\.end.seconds).filter(\.isFinite).max() ?? 0
            )
        }
        let newValue = min(max(bufferedUntil / totalTime, 0), 1)
        if abs(newValue - bufferedFraction) > 0.001 {
            bufferedFraction = newValue
        }
    }

    private func setPhase(_ newPhase: KSPlayerPresentationPhase) {
        if phase != newPhase {
            phase = newPhase
        }
        let waiting = newPhase == .preparing || newPhase == .buffering
        if waiting != isWaitingForPlayback {
            isWaitingForPlayback = waiting
        }
    }

    private func invalidateAVObservations() {
        timeControlObservation?.invalidate()
        currentItemObservation?.invalidate()
        itemStatusObservation?.invalidate()
        loadedRangesObservation?.invalidate()
        timeControlObservation = nil
        currentItemObservation = nil
        itemStatusObservation = nil
        loadedRangesObservation = nil
    }

    deinit {
        timeControlObservation?.invalidate()
        currentItemObservation?.invalidate()
        itemStatusObservation?.invalidate()
        loadedRangesObservation?.invalidate()
    }
}
