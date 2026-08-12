import Foundation
import KSPlayer

/// Owns startup/resume guards and translates KSPlayer callbacks into stable
/// UI state. Keeping these flags together prevents a view rebuild from
/// accidentally bypassing one half of the resume-protection sequence.
@MainActor
final class KSPlayerPlaybackStateCoordinator: ObservableObject {
    @Published private(set) var isPlaying = false

    private var hasReachedStartPlayTime = false
    private var hasAppliedResumeSeek = false
    private var naturalSizeReported = false
    private var autoPlayApplied = false
    private var stateLogBudget = 0

    func resetForMount() {
        autoPlayApplied = false
        stateLogBudget = 8
    }

    func handleProgress(
        current: TimeInterval,
        total: TimeInterval,
        savedSeconds: TimeInterval,
        player: KSVideoPlayer.Coordinator,
        onProgress: (TimeInterval) -> Void
    ) {
        guard current.isFinite, current >= 0 else { return }

        if savedSeconds > 1, !hasAppliedResumeSeek, total > 1.5 {
            player.seek(time: savedSeconds)
            hasAppliedResumeSeek = true
            return
        }

        if savedSeconds > 5, !hasReachedStartPlayTime {
            guard current >= savedSeconds - 2 else { return }
            hasReachedStartPlayTime = true
        }

        onProgress(current)
    }

    func handleState(
        layer: KSPlayerLayer,
        state: KSPlayerState,
        url: URL,
        autoPlay: Bool,
        onNaturalSize: (CGSize) -> Void
    ) {
        if state == .error {
            AppLogger.log("player error state url=\(url.absoluteString) isFile=\(url.isFileURL) state=\(state)")
        }
        if stateLogBudget > 0 {
            stateLogBudget -= 1
            AppLogger.log("player state=\(state) isPlaying=\(state.isPlaying)")
        }

        // Set before play/pause because KSPlayer synchronously re-enters its
        // state callback while changing from bufferFinished.
        if !autoPlayApplied, state == .bufferFinished {
            autoPlayApplied = true
            AppLogger.log("autoplay enforced: \(autoPlay ? "play" : "pause")")
            if autoPlay {
                layer.play()
            } else {
                layer.pause()
            }
        }

        isPlaying = state.isPlaying
        let size = layer.player.naturalSize
        if !naturalSizeReported, size.width > 0, size.height > 0 {
            naturalSizeReported = true
            onNaturalSize(size)
        }
    }
}
