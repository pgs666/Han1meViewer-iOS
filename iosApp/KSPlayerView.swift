import SwiftUI
import KSPlayer
import Han1meShared

/// SwiftUI 包装 KSPlayer 上游的 `KSVideoPlayerView`（完整 SwiftUI player view，
/// 内置控件 / 字幕 / PiP / 全屏 / 手势）。要求 iOS 16+。
///
/// 与底层 `KSVideoPlayer` 相比：
/// - 不需要自实现 controls overlay / 全屏 view / 手势识别
/// - KSPlayer 内置 UI 来自上游，跟随版本升级自动获得新功能（PiP、AirPlay、字幕等）
///
/// 已知 trade-off：
/// - `KSVideoPlayerView` 源码里使用 `.ignoresSafeArea()` / `.persistentSystemOverlays(.hidden)`
///   / `.toolbar(.hidden, for: .automatic)` 等"全屏向"修饰符。inline 嵌入时仍可能影响外层
///   NavigationStack。若发生破坏外层布局的现象，再考虑：① 把 KSVideoPlayerView 包到一个
///   独立的 NavigationStack 里隔离；② 改用底层 `KSVideoPlayer` + `KSVideoPlayerViewBuilder`
///   helper 拼装上游风格控件。
///
/// hanime1.me 视频 CDN 通常需要正确的 UA 和 Referer，通过 `KSOptions.appendHeader`
/// 同时写入 AVURLAsset 与 FFmpeg 两条 backend。后台音频会话通过
/// `KSOptions.setAudioSession()` 一次性激活（解决审计 P0-L1 一半）。
@MainActor
struct KSPlayerView: View {
    let snapshot: VideoDetailScreenSnapshot
    let onProgress: (TimeInterval) -> Void
    let onPlaybackEnded: () -> Void

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()

    init(
        snapshot: VideoDetailScreenSnapshot,
        onProgress: @escaping (TimeInterval) -> Void = { _ in },
        onPlaybackEnded: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.onProgress = onProgress
        self.onPlaybackEnded = onPlaybackEnded
    }

    var body: some View {
        // 一次性全局配置 KSPlayer
        let _ = Self.configureKSPlayerGlobalsOnce
        Group {
            if let primarySource = primarySource(),
               let url = URL(string: primarySource.url) {
                playerView(url: url)
            } else {
                emptyPlaceholder
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .clipped()
    }

    @ViewBuilder
    private func playerView(url: URL) -> some View {
        let resumeSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000
        let options = Self.makeKSOptions(resumeSeconds: resumeSeconds)

        KSVideoPlayerView(
            coordinator: coordinator,
            url: url,
            options: options,
            title: snapshot.title
        )
        .onAppear {
            // KSVideoPlayer.Coordinator 暴露 onPlay/onFinish 回调。
            // 设置在 onAppear 里以便 SwiftUI 重建 View 时回调闭包能反映最新的 onProgress/onPlaybackEnded。
            coordinator.onPlay = { current, _ in
                onProgress(current)
            }
            coordinator.onFinish = { _, _ in
                onPlaybackEnded()
            }
        }
    }

    private var emptyPlaceholder: some View {
        ZStack {
            Color.black
            VStack(spacing: 10) {
                Image(systemName: "play.slash")
                    .font(.title)
                    .foregroundStyle(.white)
                Text("未解析到可播放源")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Helpers

    private func primarySource() -> VideoPlaybackSourceRow? {
        snapshot.playbackSources.first(where: { $0.isDefault }) ?? snapshot.playbackSources.first
    }

    private static func makeKSOptions(resumeSeconds: TimeInterval) -> KSOptions {
        let options = KSOptions()
        // hanime1.me 视频 CDN 通常需要正确的 UA 和 Referer 才能播放。
        // 用 KSOptions.appendHeader 同时写入 AVURLAsset 和 FFmpeg 两条 backend 路径。
        options.appendHeader([
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Referer": "https://hanime1.me/",
        ])
        options.isSeekedAutoPlay = true
        options.isAccurateSeek = true
        if resumeSeconds > 1 {
            options.startPlayTime = resumeSeconds
        }
        return options
    }

    /// KSPlayer 一次性全局配置：自动播放 + 后台音频会话。
    /// 注意：`KSOptions.isAutoPlay` 在最新版 KSPlayer 是 static，不能在 instance 上设置。
    private static let configureKSPlayerGlobalsOnce: Void = {
        KSOptions.isAutoPlay = true
        KSOptions.setAudioSession()
    }()
}
