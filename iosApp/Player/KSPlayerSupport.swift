import Foundation
import KSPlayer

enum KSPlayerDragKind: Equatable {
    case none
    case seek
    case brightness
    case volume
}

enum KSPlayerDisplayFormatter {
    static let playbackRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    static func time(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainingSeconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    static func rate(_ rate: Float) -> String {
        if abs(rate - rate.rounded()) < 0.01 {
            return String(format: "%.0fx", rate)
        }
        return String(format: "%.2gx", rate)
    }
}

enum KSPlayerOptionsFactory {
    static func make(
        resumeSeconds: TimeInterval,
        autoPlay: Bool,
        playbackRate: Float,
        referer: String
    ) -> KSOptions {
        // KSPlayerLayer's initializer currently reads the global setting when
        // creating a layer, so update it before constructing the options.
        KSOptions.isAutoPlay = autoPlay
        let options = KSOptions()
        options.appendHeader([
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Referer": referer,
        ])
        options.referer = referer
        options.isSeekedAutoPlay = true
        options.isAccurateSeek = false
        options.isSecondOpen = false
        options.preferredForwardBufferDuration = 12
        options.maxBufferDuration = 60
        options.startPlayRate = playbackRate
        if resumeSeconds > 1 {
            options.startPlayTime = resumeSeconds
        }
        return options
    }
}
