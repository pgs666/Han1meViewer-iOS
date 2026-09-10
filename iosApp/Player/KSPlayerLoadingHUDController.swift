import Combine
import Foundation
import SwiftUI

/// Debounces short state transitions while ensuring every real prepare,
/// seek, or rebuffer period produces visible feedback.
@MainActor
final class KSPlayerLoadingHUDController: ObservableObject {
    @Published private(set) var isVisible = false

    private var shownAt: Date?
    private var showTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?

    func update(isWaiting: Bool) {
        if isWaiting {
            hideTask?.cancel()
            guard !isVisible else { return }
            showTask?.cancel()
            showTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                shownAt = Date()
                withAnimation(.easeInOut(duration: 0.16)) {
                    isVisible = true
                }
            }
        } else {
            showTask?.cancel()
            guard isVisible else { return }
            let elapsed = Date().timeIntervalSince(shownAt ?? .distantPast)
            let remaining = max(0, 0.35 - elapsed)
            hideTask?.cancel()
            hideTask = Task { @MainActor in
                if remaining > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                }
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.16)) {
                    isVisible = false
                }
                shownAt = nil
            }
        }
    }

    func cancel() {
        showTask?.cancel()
        hideTask?.cancel()
        showTask = nil
        hideTask = nil
        shownAt = nil
        isVisible = false
    }

    deinit {
        showTask?.cancel()
        hideTask?.cancel()
    }
}
