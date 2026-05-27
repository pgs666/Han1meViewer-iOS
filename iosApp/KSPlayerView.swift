import SwiftUI
import KSPlayer
import Han1meShared

/// SwiftUI 包装 KSPlayer 上游的 `KSVideoPlayerView`（完整 SwiftUI player，含字幕 / PiP /
/// 倍速 / 清晰度切换 / AirPlay / 长按倍速 / 滑动调音量亮度 seek 等所有功能），
/// 通过**嵌套 `NavigationStack` 隔离**它的 `.toolbar(.hidden, for: .automatic)` /
/// `.persistentSystemOverlays(.hidden)` 等"全屏向"修饰符，让外层 `VideoDetailView` 的
/// NavigationStack toolbar / status bar / 边缘返回手势不被影响。
///
/// 通过 `@Binding isFullscreen` / `@Binding isCollapsed` 让外部容器（VideoDetailView）
/// 控制 player 的展示形态：
/// - **inline**：16:9 frame，叠加最小 overlay —— 右上"全屏 toggle"按钮 + 暂停时的"收起"按钮
/// - **fullscreen**：撑满父容器（VideoDetailView 进入全屏 layout）
/// - **collapsed**：暂停后用户点收起 → 折叠为一行 strip
///
/// **关键**：KSPlayerView 始终在 SwiftUI view tree 同一位置，用 frame modifier 在外
/// 切换大小，保持 view identity 不变 → KSVideoPlayer 内部不重新 init → KSPlayerLayer
/// 不重置 → 视频不重新加载，进度不丢失。
///
/// 部署目标 iOS 16+。
@MainActor
struct KSPlayerView: View {
    let snapshot: VideoDetailScreenSnapshot
    @Binding var isFullscreen: Bool
    @Binding var isCollapsed: Bool
    let onProgress: (TimeInterval) -> Void
    let onPlaybackEnded: () -> Void

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()

    init(
        snapshot: VideoDetailScreenSnapshot,
        isFullscreen: Binding<Bool>,
        isCollapsed: Binding<Bool>,
        onProgress: @escaping (TimeInterval) -> Void = { _ in },
        onPlaybackEnded: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self._isFullscreen = isFullscreen
        self._isCollapsed = isCollapsed
        self.onProgress = onProgress
        self.onPlaybackEnded = onPlaybackEnded
    }

    var body: some View {
        let _ = Self.configureKSPlayerGlobalsOnce
        Group {
            if isCollapsed {
                collapsedStrip
            } else if let primarySource = primarySource(),
                      let url = URL(string: primarySource.url) {
                playerWithOverlays(url: url)
            } else {
                emptyPlaceholder
            }
        }
        .background(Color.black)
        .clipped()
    }

    // MARK: - Player + overlays

    @ViewBuilder
    private func playerWithOverlays(url: URL) -> some View {
        let resumeSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000
        let options = makeKSOptions(resumeSeconds: resumeSeconds)

        ZStack {
            // 嵌套 NavigationStack 隔离 KSVideoPlayerView 的 .toolbar(.hidden, for: .automatic)
            // / .persistentSystemOverlays(.hidden) 影响。这些修饰符默认作用于最近的
            // NavigationStack/Window，嵌套后只影响内层 stack，不再泄漏到外层 VideoDetailView 的 nav bar。
            NavigationStack {
                KSVideoPlayerView(
                    coordinator: coordinator,
                    url: url,
                    options: options,
                    title: snapshot.title
                )
                .onAppear {
                    coordinator.onPlay = { current, _ in
                        if current.isFinite { onProgress(current) }
                    }
                    coordinator.onFinish = { _, _ in
                        onPlaybackEnded()
                    }
                }
            }

            // 自己的 overlay 按钮（fullscreen toggle / collapse），仅在 KSVideoPlayerView
            // 控件可见时显示。coordinator.isMaskShow 是 @Published，订阅其变化自动重 render。
            if coordinator.isMaskShow {
                overlayButtons
                    .transition(.opacity)
                    .allowsHitTesting(true)
            }
        }
    }

    private var overlayButtons: some View {
        VStack {
            HStack(spacing: 8) {
                // 暂停时的收起按钮（仅非全屏时有意义）
                if !isFullscreen, !coordinator.state.isPlaying {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { isCollapsed = true }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.55), in: Circle())
                            .accessibilityLabel("收起播放器")
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                // 全屏切换按钮
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { isFullscreen.toggle() }
                } label: {
                    Image(systemName: isFullscreen
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.55), in: Circle())
                        .accessibilityLabel(isFullscreen ? "退出全屏" : "全屏")
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)
            Spacer()
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

    // MARK: - Collapsed strip

    private var collapsedStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.rectangle.fill")
                .foregroundStyle(.white)
                .font(.title2)
            Text(snapshot.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isCollapsed = false }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.55), in: Circle())
                    .accessibilityLabel("展开播放器")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    // MARK: - Helpers

    private func primarySource() -> VideoPlaybackSourceRow? {
        snapshot.playbackSources.first(where: { $0.isDefault }) ?? snapshot.playbackSources.first
    }

    private func makeKSOptions(resumeSeconds: TimeInterval) -> KSOptions {
        let options = KSOptions()
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

    /// KSPlayer 一次性全局配置：自动播放 + 后台音频会话（解决审计 P0-L1 的一半）。
    private static let configureKSPlayerGlobalsOnce: Void = {
        KSOptions.isAutoPlay = true
        KSOptions.setAudioSession()
    }()
}
