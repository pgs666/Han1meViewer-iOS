# M9: AVPlayer 错误监听

## 原始输入
M9. AVPlayer 没监听 error / failedToPlayEndTime — 视频源失效时 iOS 黑屏没提示。Android 通过 ExoPlayer 的 Player.Listener.onPlayerError 能弹"切换清晰度"。修复方向：VideoDetailViewModel 注册 AVPlayerItem.failedToPlayToEndTimeNotification 和 KVO status。

## English Summary
Added AVPlayer error monitoring to VideoDetailViewModel:
- KVO observation on AVPlayerItem.status to detect .failed state
- NotificationCenter observer for AVPlayerItem.failedToPlayToEndTime
- Published `playerError` property to surface errors to the UI
- Error overlay on VideoPlayer showing error message with dismiss button
- Proper cleanup of observers in releasePlayer()

## Changes
- `VideoDetailViewModel.swift`: Added playerError property, KVO/Notification observers, cleanup
- `VideoDetailView.swift`: Added error overlay on VideoPlayer with error message and dismiss
