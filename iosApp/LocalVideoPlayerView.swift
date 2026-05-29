import SwiftUI
import KSPlayer

/// Minimal full-screen player for a locally downloaded file. Unlike the
/// in-app streaming player (KSPlayerView, which is deeply integrated with
/// the video-detail snapshot, gestures, resume-seek, follow-finger
/// collapse, etc.) this is a plain playback surface: it just feeds a
/// file:// URL into KSPlayer's high-level KSVideoPlayerView, which brings
/// its own standard control overlay. No favorite / comment / related —
/// purely "play the file I downloaded".
struct LocalVideoPlayerView: View {
    let title: String
    let fileURL: URL

    @State private var didConfigure = false

    var body: some View {
        KSVideoPlayerView(url: fileURL, options: makeOptions())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .hidesTabBarOnAppear()
            .ignoresSafeArea(edges: .bottom)
    }

    private func makeOptions() -> KSOptions {
        KSOptions.isAutoPlay = true
        return KSOptions()
    }
}
