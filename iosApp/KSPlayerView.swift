import SwiftUI
import UIKit
import KSPlayer
import Han1meShared

/// SwiftUI 包装 KSPlayer 的 `IOSVideoPlayerView`。
///
/// 替代旧的 `VideoPlayer(player:)` AVPlayer 包装：
/// - 自动从 `VideoDetailScreenSnapshot.playbackSources` 构造多清晰度资源
/// - 注入 hanime1.me 的 User-Agent + Referer（视频 CDN 防盗链需要）
/// - 通过 `onProgress` / `onPlaybackEnded` 回调把进度同步回 ViewModel（写入本地观看历史）
/// - 长按倍速 / 双指缩放 / 全屏切换均由 KSPlayer 的 `IOSVideoPlayerView` 内置手势处理
///
/// 注：cookie 暂不注入。hanime1 的视频 URL 是带签名的 CDN 临时链接，通常不依赖会话 cookie。
/// 如果后续验证发现某些视频源 403，再在 KSPlayer 集成完成后通过
/// `SharedAppEnvironment` 暴露 cookie header 注入到 `KSOptions.avOptions`。
struct KSPlayerView: UIViewRepresentable {
    let snapshot: VideoDetailScreenSnapshot
    let onProgress: (TimeInterval) -> Void
    let onPlaybackEnded: () -> Void

    init(
        snapshot: VideoDetailScreenSnapshot,
        onProgress: @escaping (TimeInterval) -> Void = { _ in },
        onPlaybackEnded: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.onProgress = onProgress
        self.onPlaybackEnded = onPlaybackEnded
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(onProgress: onProgress, onPlaybackEnded: onPlaybackEnded)
    }

    func makeUIView(context: Context) -> KSPlayerContainerView {
        // 一次性全局配置 KSPlayer：自动播放 + 后台音频会话（解决审计 P0-L1 的一半）
        _ = Self.configureKSPlayerGlobalsOnce
        let container = KSPlayerContainerView()
        let playerView = container.playerView
        // 进度回调
        playerView.playTimeDidChange = { [weak playerView] currentTime, _ in
            context.coordinator.onProgress(currentTime)
            _ = playerView // 维持 weak 引用一致性
        }
        // 装入资源
        if let resource = Self.makeResource(from: snapshot) {
            playerView.set(resource: resource)
        }
        context.coordinator.attachEndedObserver(to: playerView)
        return container
    }

    func updateUIView(_ container: KSPlayerContainerView, context: Context) {
        // snapshot 变化时（如切换清晰度/视频）重新装入资源
        if context.coordinator.lastVideoCode != snapshot.videoCode {
            if let resource = Self.makeResource(from: snapshot) {
                container.playerView.set(resource: resource)
            }
            context.coordinator.lastVideoCode = snapshot.videoCode
        }
    }

    static func dismantleUIView(_ container: KSPlayerContainerView, coordinator: Coordinator) {
        coordinator.detach()
        container.playerView.pause()
    }

    // MARK: - Coordinator

    final class Coordinator {
        let onProgress: (TimeInterval) -> Void
        let onPlaybackEnded: () -> Void
        var lastVideoCode: String = ""
        private var endedObserver: NSObjectProtocol?

        init(
            onProgress: @escaping (TimeInterval) -> Void,
            onPlaybackEnded: @escaping () -> Void
        ) {
            self.onProgress = onProgress
            self.onPlaybackEnded = onPlaybackEnded
        }

        func attachEndedObserver(to playerView: IOSVideoPlayerView) {
            endedObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.onPlaybackEnded()
            }
        }

        func detach() {
            if let endedObserver {
                NotificationCenter.default.removeObserver(endedObserver)
                self.endedObserver = nil
            }
        }

        deinit {
            detach()
        }
    }

    // MARK: - Resource 构造

    private static func makeResource(from snapshot: VideoDetailScreenSnapshot) -> KSPlayerResource? {
        let sources = snapshot.playbackSources
        guard !sources.isEmpty else {
            return nil
        }

        var definitions: [KSPlayerResourceDefinition] = []
        // 默认源排第一（KSPlayer 选第一个 definition 作为 default）
        let defaultIndex: Int = sources.firstIndex(where: { $0.isDefault }) ?? 0
        let orderedIndices: [Int] = [defaultIndex] + sources.indices.filter { $0 != defaultIndex }

        let resumeSeconds = TimeInterval(snapshot.playbackPositionMillis) / 1000

        for index in orderedIndices {
            let source = sources[index]
            guard let url = URL(string: source.url) else {
                continue
            }
            let options = makeKSOptions(resumeSeconds: resumeSeconds)
            definitions.append(
                KSPlayerResourceDefinition(
                    url: url,
                    definition: source.label,
                    options: options
                )
            )
        }
        guard !definitions.isEmpty else { return nil }

        var coverURL: URL?
        if let coverString = snapshot.coverUrl {
            coverURL = URL(string: coverString)
        }

        return KSPlayerResource(
            name: snapshot.title,
            definitions: definitions,
            cover: coverURL
        )
    }

    private static func makeKSOptions(resumeSeconds: TimeInterval) -> KSOptions {
        let options = KSOptions()
        // hanime1.me 视频 CDN 通常需要正确的 UA 和 Referer 才能播放。
        // 用 KSOptions.appendHeader 同时写入 AVURLAsset 和 FFmpeg 两条 backend 路径。
        // UA 与项目其他 WKWebView 入口（LoginView / CloudflareChallengeView）保持一致 —
        // KMP 端 `HanimeNetworkDefaults.DEFAULT_USER_AGENT` 是 `const val`，Swift 不可访问。
        options.appendHeader([
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Referer": "https://hanime1.me/",
        ])
        // seek 后自动恢复播放、精确 seek、恢复进度
        options.isSeekedAutoPlay = true
        options.isAccurateSeek = true
        if resumeSeconds > 1 {
            options.startPlayTime = resumeSeconds
        }
        return options
    }

    /// KSPlayer 一次性全局配置：自动播放 + 后台音频会话（解决审计 P0-L1 的一半）。
    /// 注意：`KSOptions.isAutoPlay` 在最新版 KSPlayer 是 static，不能在 instance 上设置。
    private static let configureKSPlayerGlobalsOnce: Void = {
        KSOptions.isAutoPlay = true
        KSOptions.setAudioSession()
    }()
}

/// 包裹 `IOSVideoPlayerView` 的容器 UIView。
///
/// 直接把 `IOSVideoPlayerView` 作为 SwiftUI `UIViewRepresentable` 的 root view 时，
/// SwiftUI 给的 `aspectRatio(16/9)` 约束会被 KSPlayer 内部 Auto Layout 约束覆盖（
/// 它内部 toolbar / cover overlay 等子视图有自己的 size 约束），导致 player view
/// 实际高度远超 16:9。
///
/// 解决：用一个普通 UIView 接受 SwiftUI 给的 frame 约束，再用 fill constraints
/// 把 IOSVideoPlayerView 撑满容器。这样 player view 的实际尺寸 = SwiftUI 给的 frame，
/// 且容器开启 `clipsToBounds` / `layer.masksToBounds` 防止 KSPlayer 内部 overlay 越界。
final class KSPlayerContainerView: UIView {
    let playerView: IOSVideoPlayerView

    override init(frame: CGRect) {
        playerView = IOSVideoPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        layer.masksToBounds = true
        backgroundColor = .black

        addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 让 SwiftUI 完全控制 layout，不让 UIKit auto layout 自己算 intrinsic size。
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}

// MARK: - End
