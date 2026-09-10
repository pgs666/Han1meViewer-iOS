import Combine
import Foundation

/// Converts repeated, genuine rebuffer events into an optional one-step
/// quality reduction. It never acts unless the user enabled the setting.
@MainActor
final class KSPlayerAdaptiveQualityController: ObservableObject {
    @Published private(set) var noticeQuality: String?

    private var wasBuffering = false
    private var hasPlayedCurrentSource = false
    private var recentRebufferDates: [Date] = []
    private var lastAutomaticChange: Date?
    private var noticeTask: Task<Void, Never>?

    func markPlayable() {
        hasPlayedCurrentSource = true
    }

    func resetForNewSource() {
        wasBuffering = false
        hasPlayedCurrentSource = false
        recentRebufferDates.removeAll()
    }

    func sourceForRebufferTransition(
        isBuffering: Bool,
        enabled: Bool,
        activeSource: VideoPlaybackSourceRow?,
        sources: [VideoPlaybackSourceRow],
        now: Date = Date()
    ) -> VideoPlaybackSourceRow? {
        let enteredBuffering = isBuffering && !wasBuffering
        wasBuffering = isBuffering
        guard enteredBuffering, hasPlayedCurrentSource, enabled, let activeSource else {
            return nil
        }

        recentRebufferDates = recentRebufferDates.filter { now.timeIntervalSince($0) <= 45 }
        recentRebufferDates.append(now)
        guard recentRebufferDates.count >= 2 else { return nil }
        if let lastAutomaticChange, now.timeIntervalSince(lastAutomaticChange) < 60 {
            return nil
        }
        guard let currentResolution = resolution(from: activeSource.label) else { return nil }
        let lowerSource = sources
            .compactMap { source -> (VideoPlaybackSourceRow, Int)? in
                guard source.id != activeSource.id,
                      let resolution = resolution(from: source.label),
                      resolution < currentResolution else { return nil }
                return (source, resolution)
            }
            .max(by: { $0.1 < $1.1 })?
            .0
        if lowerSource != nil {
            lastAutomaticChange = now
        }
        return lowerSource
    }

    func showAutomaticChange(to quality: String) {
        noticeQuality = quality
        noticeTask?.cancel()
        noticeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            noticeQuality = nil
        }
    }

    func clearNotice() {
        noticeTask?.cancel()
        noticeTask = nil
        noticeQuality = nil
    }

    private func resolution(from label: String) -> Int? {
        label.split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
            .first
    }

    deinit {
        noticeTask?.cancel()
    }
}
