import AVFoundation
import SwiftUI

@MainActor
final class KSPlayerNetworkSpeedSampler: ObservableObject {
    private var lastLoadedEnd: Double = 0
    private var lastSampleAt: Date?

    func reset() {
        lastLoadedEnd = 0
        lastSampleAt = nil
    }

    func avPlayer(from player: Any?) -> AVPlayer? {
        guard let player else { return nil }
        return findAVPlayer(in: player)
    }

    /// Reaches the AVPlayer wrapped by KSPlayer and returns its current
    /// transfer speed when enough information is available.
    func sample(player: Any?) -> String? {
        guard let avPlayer = avPlayer(from: player) else { return nil }
        guard let item = avPlayer.currentItem else { return nil }

        if let event = item.accessLog()?.events.last {
            let bitsPerSecond = event.observedBitrate
            if bitsPerSecond > 0 {
                return format(bytesPerSecond: bitsPerSecond / 8.0)
            }
            let bytes = event.numberOfBytesTransferred
            let duration = event.transferDuration
            if bytes > 0, duration > 0 {
                return format(bytesPerSecond: Double(bytes) / duration)
            }
        }

        return synthesisedSpeed(from: item)
    }

    private func synthesisedSpeed(from item: AVPlayerItem) -> String? {
        let now = Date()
        guard
            let lastRange = item.loadedTimeRanges.last?.timeRangeValue,
            lastRange.duration.isNumeric,
            lastRange.start.isNumeric
        else { return nil }
        let currentEnd = lastRange.start.seconds + lastRange.duration.seconds

        let previousEnd = lastLoadedEnd
        let previousTime = lastSampleAt
        lastLoadedEnd = currentEnd
        lastSampleAt = now

        guard let previousTime else { return nil }
        let wallDelta = now.timeIntervalSince(previousTime)
        guard wallDelta > 0.1 else { return nil }
        let bufferDelta = currentEnd - previousEnd
        guard bufferDelta > 0 else { return nil }
        let fillRate = bufferDelta / wallDelta

        let bitrate: Float = item.tracks
            .compactMap { $0.assetTrack }
            .first { $0.mediaType == .video }?.estimatedDataRate ?? 0
        guard bitrate > 0 else { return nil }
        return format(bytesPerSecond: Double(bitrate) / 8.0 * fillRate)
    }

    private func findAVPlayer(in value: Any, depth: Int = 0) -> AVPlayer? {
        guard depth < 4 else { return nil }
        if let player = value as? AVPlayer { return player }
        for child in Mirror(reflecting: value).children {
            if let player = findAVPlayer(in: child.value, depth: depth + 1) {
                return player
            }
        }
        return nil
    }

    private func format(bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000)
        }
        if bytesPerSecond >= 1_000 {
            return String(format: "%.0f KB/s", bytesPerSecond / 1_000)
        }
        return String(format: "%.0f B/s", bytesPerSecond)
    }
}
