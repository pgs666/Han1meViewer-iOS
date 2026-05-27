import SwiftUI
import KSPlayer
import Han1meShared

/// SwiftUI 包装 KSPlayer 的底层 `KSVideoPlayer`（仅显示视频内容，无内置 UI）。
///
/// 通过 `@Binding isFullscreen` / `@Binding isCollapsed` 让外部容器（VideoDetailView）
/// 控制 player 的展示形态：
/// - **inline**：16:9 frame，叠加最小控件（中央播放/暂停 + 右上全屏按钮 + 暂停时的"收起"按钮）
/// - **fullscreen**：撑满父容器（VideoDetailView 进入全屏 layout）
/// - **collapsed**：暂停后用户点收起 → 折叠为一行高度，显示"展开"按钮
///
/// **关键**：KSPlayerView 始终在 SwiftUI view tree 同一位置，用 frame modifier 在外
/// 切换大小，保持 view identity 不变 → KSVideoPlayer.makeUIView 不重新调用 →
/// KSPlayerLayer 不重置 → 视频不重新加载，进度不丢失。
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
    @State private var showsControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isPlaying = false

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
                playerWithControls(url: url)
            } else {
                emptyPlaceholder
            }
        }
        .background(Color.black)
        .clipped()
    }

    // MARK: - Player + controls

    @ViewBuilder
    private func playerWithControls(url: URL) -> some View {
        let resumeSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000
        let options = makeKSOptions(resumeSeconds: resumeSeconds)

        ZStack {
            KSVideoPlayer(coordinator: coordinator, url: url, options: options)
                .onPlay { current, _ in
                    if current.isFinite { onProgress(current) }
                }
                .onFinish { _, _ in
                    onPlaybackEnded()
                }
                .onStateChanged { _, state in
                    isPlaying = state.isPlaying
                }

            if showsControls {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            togglePlayPause()
            scheduleAutoHide()
        }
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.18)) { showsControls.toggle() }
            if showsControls { scheduleAutoHide() }
        }
        .onAppear { scheduleAutoHide() }
        .onDisappear { hideControlsTask?.cancel() }
    }

    private var controlsOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.4), .clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack {
                HStack(spacing: 8) {
                    // 暂停时显示"收起"按钮（只在非全屏时有意义）
                    if !isPlaying && !isFullscreen {
                        collapseButton
                    }
                    Spacer()
                    fullscreenButton
                }
                Spacer()
                centerPlayPauseButton
                Spacer()
            }
            .padding(12)
        }
    }

    private var fullscreenButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isFullscreen.toggle()
            }
        } label: {
            Image(systemName: isFullscreen
                  ? "arrow.down.right.and.arrow.up.left"
                  : "arrow.up.left.and.arrow.down.right")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.45), in: Circle())
                .accessibilityLabel(isFullscreen ? "退出全屏" : "全屏")
        }
        .buttonStyle(.plain)
    }

    private var collapseButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCollapsed = true
            }
        } label: {
            Image(systemName: "chevron.up")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.45), in: Circle())
                .accessibilityLabel("收起播放器")
        }
        .buttonStyle(.plain)
    }

    private var centerPlayPauseButton: some View {
        Button {
            togglePlayPause()
            scheduleAutoHide()
        } label: {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 60, weight: .regular))
                .foregroundStyle(.white)
                .shadow(radius: 4)
                .accessibilityLabel(isPlaying ? "暂停" : "播放")
        }
        .buttonStyle(.plain)
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
                withAnimation(.easeInOut(duration: 0.25)) {
                    isCollapsed = false
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.45), in: Circle())
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

    private func togglePlayPause() {
        guard let layer = coordinator.playerLayer else { return }
        if isPlaying { layer.pause() } else { layer.play() }
    }

    private func scheduleAutoHide() {
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000) // 4.5s
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                showsControls = false
            }
        }
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
