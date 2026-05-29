import SwiftUI
import KSPlayer

/// Full-screen player for a locally-downloaded file. Reuses the project's
/// custom KSPlayerView (gestures, fullscreen auto-rotate, quality menu,
/// resume seek, floating back button) by feeding it a synthetic
/// VideoDetailScreenSnapshot whose single playback source is the local
/// file:// URL. Purely playback — no favorite / comments / related.
struct LocalVideoPlayerView: View {
    let title: String
    let fileURL: URL

    @State private var isFullscreen = false
    @State private var isCollapsed = false
    @State private var videoNaturalSize: CGSize?
    /// Mirrors the streaming detail page's preference so portrait videos
    /// can stay portrait in fullscreen.
    @AppStorage("force_portrait_fullscreen_for_vertical_videos")
    private var forcePortraitForVerticalVideos: Bool = true

    @Environment(\.dismiss) private var dismiss

    private var snapshot: VideoDetailScreenSnapshot {
        VideoDetailScreenSnapshot.local(
            videoCode: "local",
            title: title,
            fileURL: fileURL,
            coverUrl: nil,
            playbackPositionMillis: 0
        )
    }

    var body: some View {
        KSPlayerView(
            snapshot: snapshot,
            isFullscreen: $isFullscreen,
            isCollapsed: $isCollapsed,
            onBack: { dismiss() },
            onNaturalSize: { size in videoNaturalSize = size }
        )
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .hidesTabBarOnAppear()
        .statusBarHidden(isFullscreen)
        .ignoresSafeArea(edges: isFullscreen ? .all : [])
        .onDisappear {
            if isFullscreen {
                AppOrientationController.shared.unlockAfterFullscreen()
            }
        }
        .onValueChange(of: isFullscreen) { newValue in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                if newValue {
                    AppOrientationController.shared.lockForFullscreen(to: fullscreenOrientation)
                } else {
                    AppOrientationController.shared.unlockAfterFullscreen()
                }
            }
        }
    }

    private var fullscreenOrientation: VideoFullscreenOrientation {
        let isPortraitVideo: Bool = {
            guard let size = videoNaturalSize else { return false }
            return size.height > size.width
        }()
        if isPortraitVideo && forcePortraitForVerticalVideos {
            return .portrait
        }
        return .landscape
    }
}
