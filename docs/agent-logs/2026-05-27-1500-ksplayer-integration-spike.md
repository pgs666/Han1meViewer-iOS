# Agent Log: KSPlayer 集成 Spike

- 时间：2026-05-27 15:00 CST
- 分支：`feature/ksplayer`
- 关联：Round 3 审计 P0-L1（后台音频/PiP/锁屏控件未集成）；用户对中国式播放器手势（长按倍速、双指缩放、全屏）的明确需求

## 用户输入

原文：

```text
https://github.com/kingslay/KSPlayer 试试换用这个呢
按你的建议吧，如果最终效果好就转成gpl，现在先开始集成
记住：这个项目编译验证必须推送到GitHub进行ci
```

英译：

```text
Try using https://github.com/kingslay/KSPlayer instead.
Go with your recommendation: if the final result is good we'll switch to GPL. Start the integration now.
Remember: this project's build verification must be done on GitHub CI (push-triggered).
```

## 背景

Round 3 审计的 P0-L1 标记 iOS 端后台音频 / PiP / 锁屏控件完全未集成，且用户希望播放器支持长按倍速、双指缩放、全屏等中国用户习惯的手势。原方案是先实施 P0-L1（在现有 AVPlayer 基础上加 AVAudioSession + AVPictureInPictureController + MPNowPlayingInfoCenter），但工作量较大且不能一并满足手势需求。

讨论后选定 KSPlayer（kingslay/KSPlayer）作为播放器框架——基于 AVPlayer + FFmpeg、原生支持 SwiftUI/UIKit、内置完整中国式播放器 UI（滑动调音量/亮度/seek、全屏切换）。

KSPlayer 默认 GPL-3.0 许可证，与项目当前的 Apache 2.0 不兼容（GPL 是强 copyleft）。用户决定：先做集成 spike，如果最终效果好就把项目 LICENSE 转为 GPL-3.0；如果效果不行再换方案。

## 已完成的改动

### 新建分支

- `feature/ksplayer` 从 `fix/review-bugs-performance-quality` 创建
- 同步删除了之前误创的 `feature/sj-video-player` 空分支

### 1. `project.yml`

- 在 `packages` 下加入 `KSPlayer`，使用 `branch: main`（KSPlayer README 推荐）
- 在 `Han1meViewer.dependencies` 下加入 `package: KSPlayer, product: KSPlayer`
- KSPlayer 自身依赖 `FFmpegKit` + `DisplayCriteria`，SwiftPM 会自动解析（需 CI 验证下载）

### 2. 新文件 `iosApp/KSPlayerView.swift`（187 行）

SwiftUI `UIViewRepresentable` 包装 `IOSVideoPlayerView`：

- `makeResource(from snapshot:)`：把 KMP `VideoDetailScreenSnapshot.playbackSources` 转成 `KSPlayerResource(definitions: [KSPlayerResourceDefinition])`，默认源排第一
- `makeKSOptions`：注入 hanime1.me 的 `User-Agent`（与 LoginView/CloudflareChallengeView 内联 UA 保持一致）和 `Referer: https://hanime1.me/`，通过 `avOptions["AVURLAssetHTTPHeaderFieldsKey"]` 传给 AVPlayer 的 `AVURLAsset`
- 自动播放 + 精确 seek + 恢复进度（基于 `snapshot.playbackPositionMillis`，通过 `KSOptions.startPlayTime` 在每个 definition 的 options 设置）
- `Coordinator.attachEndedObserver` 监听 `AVPlayerItemDidPlayToEndTime`，回调 `onPlaybackEnded`
- `playTimeDidChange` 回调 `onProgress(seconds)`，写回 ViewModel 的 `recordPlaybackPosition(seconds:)`
- `dismantleUIView` 时清理 observer + 暂停 player

设计取舍：
- **cookie 暂不注入**。hanime1.me 的视频 URL 是带签名的 CDN 临时链接，通常不依赖会话 cookie。如果 CI/真机验证发现某些视频源 403 才扩展（届时通过 `SharedAppEnvironment` 暴露 cookie header 接口）。
- KMP 端 `HanimeNetworkDefaults.DEFAULT_USER_AGENT` 是 `const val`，Swift 不可访问（审计 P3-N7 已记录）。**沿用项目内 inline 字符串**（与 LoginView / CloudflareChallengeView 保持一致），以后统一 P1-N1 时再替换。

### 3. `iosApp/VideoDetailViewModel.swift`

- 新增公开方法 `recordPlaybackPosition(seconds: TimeInterval)`：与现有 `persistPlaybackPosition()` 等价，但不依赖 `self.player`，供外部播放器（KSPlayerView）回调使用
- 其他字段（`@Published player`, `selectedPlaybackSourceID`, `selectedPlaybackRate`, `preparePlayer`, `selectPlaybackSource`, `configurePlayer`, KVO observers 等）**保留为 dead code**——为减小本次 spike 的破坏面；后续 P1-S53（VideoDetailViewModel 拆分）会清理

### 4. `iosApp/VideoDetailView.swift`

- `AndroidStylePlayerHeader` 整体重写：删除清晰度 Picker、倍速 Picker、外部全屏按钮、`fullScreenCover`、`onAppear preparePlayer`、`onValueChange selectPlaybackSource` 等。`body` 仅渲染 `playerSurface`
- `playerSurface` 现在用 `KSPlayerView` 替代原 `VideoPlayer(player:)`，进度回调写入 ViewModel
- 删除了顶部 `import AVKit`（KSPlayer 接管后不再直接使用 AVKit）
- 删除了 dead code `FullscreenVideoPlayer` 和 `FullscreenVideoMetrics`（共 ~94 行）——它们原本提供独立的 SwiftUI 全屏，现在由 KSPlayer 内置 toolbar 全屏按钮处理

文件行数：原约 681 行 → 现 587 行。

## 故意未做的改动（留作 spike 验证后决策）

1. **长按倍速 / 双指缩放手势扩展**：KSPlayer 的 `IOSVideoPlayerView` 内置滑动调音量/亮度/seek + 全屏切换，但长按倍速和双指缩放是否内置 README 未明示。等 CI 构建通过 + 真机/模拟器验证后再决定是否在 `KSPlayerView` 添加 `UILongPressGestureRecognizer` + `UIPinchGestureRecognizer` 包装层
2. **VideoDetailViewModel 内 dead 代码清理**：`@Published player: AVPlayer?`、`preparePlayer`、`configurePlayer`、`selectPlaybackSource`、`selectPlaybackRate`、KVO observation 等保留。属于 P1-S53 重构范围，本次 spike 不动以减小回归面
3. **后台音频 / PiP / NowPlayingInfoCenter 集成（P0-L1）**：KSPlayer 应内置 PiP 与后台播放支持，但需要 entitlements 已含 `audio` background mode（项目已具备）+ Swift 端调 `AVAudioSession.setCategory(.playback)`。等 spike 验证后统一在批次 1 P0 修复中加上
4. **License 切换**：用户已表态"如果效果好就转 GPL"。本次 spike 阶段保留 Apache 2.0；验证 OK 后再修改 LICENSE + README + 项目元数据

## 验证策略

由于本地（Linux 环境）无法跑 `xcodebuild`，验证必须经过 GitHub Actions 的 macOS runner：

1. 本地 commit + push 到 `feature/ksplayer`
2. 在 GitHub 创建 **Draft PR** 到 `feature/ios-kmp-mvp`（项目当前活跃 dev 分支），自动触发 `pull_request` workflow
3. CI 步骤：
   - 跑 `:shared:jvmTest`（应不受影响）
   - `xcodegen generate`（验证 project.yml 修改语法正确）
   - `xcodebuild build -sdk iphoneos`（验证 KSPlayer SwiftPM 解析 + 包链接 + Swift 桥接）
   - 上传 unsigned IPA artifact（用于真机验证大小）

## 已知风险与监测点

| 风险 | 严重度 | 监测方式 |
|------|--------|---------|
| FFmpegKit binaryTarget 下载失败 / 体积过大（预估 +30-80 MB） | 高 | CI artifact size 检查 |
| KSPlayer SwiftPM 与项目 KMP framework 链接冲突 | 中 | xcodebuild 日志 |
| iOS 15 部署目标兼容性（KSPlayer 要求 iOS 13+） | 低 | xcodebuild |
| `IOSVideoPlayerView` 自身的旋转管理 与项目 `AppOrientationController` 冲突 | 中 | 真机/模拟器验证 |
| `KSOptions.avOptions["AVURLAssetHTTPHeaderFieldsKey"]` 实际是否生效（hanime1 视频源 403？） | 中 | 真机播放验证 |
| 进度恢复（`startPlayTime`）行为 | 中 | 真机验证 |

## 后续步骤

1. 本地 commit（不直接推送）
2. 用户确认无误后 push 到 `origin/feature/ksplayer`
3. 创建 Draft PR 到 `feature/ios-kmp-mvp`，等待 CI 跑完
4. 根据 CI 结果决定：
   - 通过 + 真机表现好 → 转 GPL-3.0 LICENSE，扩展手势（如需要），合并到主线
   - 通过但 UX 缺手势 → 给 `KSPlayerView` 加自定义手势 overlay
   - 失败（链接 / 体积 / 兼容性问题）→ 切回自实现 SwiftUI 播放器路线（审计 fix-plan-round3.md 中 P0-L1 的备选方案）

## 修改文件清单

- `project.yml`（+5 行）
- `iosApp/KSPlayerView.swift`（新建 187 行）
- `iosApp/VideoDetailView.swift`（-94 行 dead code +约 50 行新 playerSurface）
- `iosApp/VideoDetailViewModel.swift`（+13 行 `recordPlaybackPosition(seconds:)`）

净改动：约 +160 行，-94 行。
