import SwiftUI

/// Centralizes mount/unmount cleanup and observer-driven side effects so the
/// player surface remains focused on rendering and KSPlayer callbacks.
struct KSPlayerLifecycleModifier: ViewModifier {
    @ObservedObject var volumeObserver: SystemVolumeObserver
    let isWaitingForPlayback: Bool
    let onAppear: () -> Void
    let onDisappear: () -> Void
    let onWaitingChanged: (Bool) -> Void
    let onPhysicalVolumeChanged: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
            .onValueChange(of: isWaitingForPlayback, perform: onWaitingChanged)
            .onReceive(volumeObserver.$changeTick) { _ in
                onPhysicalVolumeChanged()
            }
    }
}
