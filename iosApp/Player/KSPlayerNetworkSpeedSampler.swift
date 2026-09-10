import AVFoundation
import Combine
import Foundation
import KSPlayer

/// Samples transfer deltas instead of presenting AVPlayer's lifetime average
/// as an instantaneous speed. A small exponential moving average keeps the HUD
/// readable without hiding real changes in throughput.
@MainActor
final class KSPlayerNetworkSpeedSampler: ObservableObject {
    private weak var sampledItem: AVPlayerItem?
    private var lastBytesTransferred: Int64?
    private var lastLoadedEnd: Double?
    private var lastSampleAt: Date?
    private var smoothedBytesPerSecond: Double?
    private var idleSampleCount = 0

    func reset() {
        sampledItem = nil
        lastBytesTransferred = nil
        lastLoadedEnd = nil
        lastSampleAt = nil
        smoothedBytesPerSecond = nil
        idleSampleCount = 0
    }

    func avPlayer(from player: Any?) -> AVPlayer? {
        if let ksAVPlayer = player as? KSAVPlayer {
            return ksAVPlayer.player
        }
        return player as? AVPlayer
    }

    func sample(player: Any?) -> String? {
        guard let avPlayer = avPlayer(from: player), let item = avPlayer.currentItem else {
            reset()
            return nil
        }
        if sampledItem !== item {
            reset()
            sampledItem = item
        }

        let now = Date()
        let totalBytes = item.accessLog()?.events.reduce(Int64(0)) { partial, event in
            partial + max(event.numberOfBytesTransferred, 0)
        }
        let loadedEnd = bufferedEnd(for: item)
        let previousDate = lastSampleAt
        let previousBytes = lastBytesTransferred
        let previousLoadedEnd = lastLoadedEnd

        lastSampleAt = now
        lastBytesTransferred = totalBytes
        lastLoadedEnd = loadedEnd

        var rawSpeed: Double?
        if let previousDate {
            let elapsed = now.timeIntervalSince(previousDate)
            if elapsed >= 0.25,
               let totalBytes,
               let previousBytes,
               totalBytes > previousBytes {
                rawSpeed = Double(totalBytes - previousBytes) / elapsed
            } else if elapsed >= 0.25,
                      let loadedEnd,
                      let previousLoadedEnd,
                      loadedEnd > previousLoadedEnd,
                      let bitsPerSecond = estimatedMediaBitrate(for: item) {
                rawSpeed = ((loadedEnd - previousLoadedEnd) / elapsed) * bitsPerSecond / 8
            }
        }

        // Access-log values are an empirical session average, not an
        // instantaneous sample. Use one only to avoid an empty first HUD frame.
        if rawSpeed == nil, smoothedBytesPerSecond == nil,
           let observed = item.accessLog()?.events.last?.observedBitrate,
           observed > 0 {
            rawSpeed = observed / 8
        }

        if let rawSpeed, rawSpeed.isFinite, rawSpeed > 0 {
            idleSampleCount = 0
            let alpha = 0.35
            let smoothed = smoothedBytesPerSecond.map {
                alpha * rawSpeed + (1 - alpha) * $0
            } ?? rawSpeed
            smoothedBytesPerSecond = smoothed
            return format(bytesPerSecond: smoothed)
        }

        idleSampleCount += 1
        // Short gaps are common between HLS segments. Keep the last stable
        // value briefly, then hide it rather than displaying a misleading 0.
        if idleSampleCount <= 3, let smoothedBytesPerSecond {
            return format(bytesPerSecond: smoothedBytesPerSecond)
        }
        return nil
    }

    private func bufferedEnd(for item: AVPlayerItem) -> Double? {
        item.loadedTimeRanges
            .map(\.timeRangeValue.end.seconds)
            .filter(\.isFinite)
            .max()
    }

    private func estimatedMediaBitrate(for item: AVPlayerItem) -> Double? {
        let bitrate = item.tracks
            .compactMap(\.assetTrack)
            .reduce(Float(0)) { $0 + max($1.estimatedDataRate, 0) }
        return bitrate > 0 ? Double(bitrate) : nil
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
