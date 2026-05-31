import AVFoundation
import Combine
import Foundation

/// Observes the **system output volume** via KVO on `AVAudioSession`'s
/// `outputVolume`, so the player can show its own HUD when the user presses
/// the hardware volume buttons.
///
/// Why this is needed: `SystemVolumeController` mounts a hidden `MPVolumeView`
/// while the player is on-screen, which has the side effect of suppressing
/// iOS's own system volume HUD (intentional — we want our overlay, not the
/// system one, on top of the video). But suppressing the system HUD with
/// nothing to replace it leaves volume-key presses with no visible feedback.
/// This observer is the missing replacement: KVO on `outputVolume` fires
/// whenever the value changes (whether from a hardware key, a programmatic
/// `setVolume`, or the volume-swipe gesture), and the view layer decides
/// whether to show its physical-key HUD based on `dragState`.
@MainActor
final class SystemVolumeObserver: ObservableObject {
    /// Latest observed system output volume in [0, 1].
    @Published private(set) var outputVolume: Float = AVAudioSession.sharedInstance().outputVolume

    /// Bumped every time the value actually changes. The view watches this
    /// (rather than `outputVolume` directly) so a no-op KVO callback — e.g.
    /// the redundant notification iOS sometimes posts on first MPVolumeView
    /// mount — does not pop the HUD.
    @Published private(set) var changeTick: UInt64 = 0

    private var observation: NSKeyValueObservation?

    func start() {
        guard observation == nil else { return }
        let session = AVAudioSession.sharedInstance()
        outputVolume = session.outputVolume
        observation = session.observe(\.outputVolume, options: [.new, .old]) { [weak self] _, change in
            guard
                let self,
                let new = change.newValue,
                let old = change.oldValue,
                new != old
            else { return }
            // KVO callbacks aren't guaranteed on the main thread; hop back.
            Task { @MainActor [self] in
                self.outputVolume = new
                self.changeTick &+= 1
            }
        }
    }

    func stop() {
        observation?.invalidate()
        observation = nil
    }

    deinit {
        observation?.invalidate()
    }
}
