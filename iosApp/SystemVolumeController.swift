import AVFoundation
import MediaPlayer
import UIKit

/// Set / read the **system** output volume (the same one the hardware buttons
/// control) by reaching into a hidden `MPVolumeView`'s `UISlider` subview.
/// iOS does not expose a direct setter for `AVAudioSession.outputVolume`, so
/// this is the conventional approach (Bilibili / 哔哩哔哩 / iina / KSPlayer's
/// own demo all use the same trick).
///
/// **Important**: as soon as a visible `MPVolumeView` (even alpha ~0) is in
/// the view hierarchy, iOS hands the system volume HUD ownership over to it
/// and stops showing its own HUD on hardware-button presses — anywhere in the
/// app. To avoid suppressing the system HUD outside the player, we keep this
/// ref-counted: `acquire()` mounts the hidden view, `release()` unmounts it.
/// `KSPlayerView` calls acquire on `.onAppear` and release on `.onDisappear`.
@MainActor
enum SystemVolumeController {
    private static var volumeView: MPVolumeView?
    private static var refCount = 0

    /// Increment the active-player count and mount the hidden volume view if
    /// this is the first acquirer.
    static func acquire() {
        refCount += 1
        if volumeView == nil {
            mount()
        }
    }

    /// Decrement the active-player count; if no players remain, remove the
    /// hidden view so iOS resumes showing its own system volume HUD anywhere
    /// else in the app.
    static func release() {
        refCount = max(0, refCount - 1)
        if refCount == 0 {
            unmount()
        }
    }

    private static func mount() {
        guard let window = activeWindow() else { return }
        let v = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
        v.isHidden = false
        v.alpha = 0.0001
        v.showsRouteButton = false
        window.addSubview(v)
        volumeView = v
    }

    private static func unmount() {
        volumeView?.removeFromSuperview()
        volumeView = nil
    }

    private static func activeWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first
    }

    private static var slider: UISlider? {
        volumeView?.subviews.lazy.compactMap { $0 as? UISlider }.first
    }

    /// Current system output volume in [0, 1]. Reads the shared
    /// `AVAudioSession.outputVolume` directly because that's authoritative.
    static func currentVolume() -> Float {
        AVAudioSession.sharedInstance().outputVolume
    }

    /// Programmatically set the system output volume in [0, 1]. No-op if no
    /// caller has currently acquired the controller (slider unavailable).
    static func setVolume(_ value: Float) {
        guard volumeView != nil else { return }
        // Apple recommends dispatching to the next runloop so MPVolumeView
        // has a chance to lay out its private subviews on first use.
        DispatchQueue.main.async {
            slider?.value = max(0, min(1, value))
        }
    }
}
