# M9: AVPlayer 错误监听

## User Input

Original:
M9. AVPlayer 没监听 error / failedToPlayEndTime — 视频源失效时 iOS 黑屏没提示。Android 通过 ExoPlayer 的 Player.Listener.onPlayerError 能弹"切换清晰度"。

English translation:
M9. AVPlayer has no error/failedToPlayEndTime listener — when a video source fails, iOS shows a black screen with no feedback. Android can show "switch resolution" via ExoPlayer's Player.Listener.onPlayerError.

## What Changed
- `VideoDetailViewModel.swift`:
  - Added `@Published var playerError: String?` property
  - Added `playerItemStatusObservation` (KVO) to detect `.failed` status
  - Added `failedToPlayObserver` (NotificationCenter) for `AVPlayerItemFailedToPlayToEndTime`
  - Added `observePlayerItemErrors()` and `removePlayerObservers()` methods
  - Cleanup in `releasePlayer()`
- `VideoDetailView.swift`: Added error overlay on VideoPlayer with error message and dismiss button

## Why Changed
- Video source failures showed black screen with no user feedback
- Review item M9 from `review-ios-vs-android.md`

## Verification
- CI passed after fix (run 26435784946, completed success)

## Mistakes
- Initial implementation placed observer methods outside the class due to Python string replacement ordering issue
- Caused "Extraneous '}' at top level" compilation error
- Fixed by moving methods back inside `VideoDetailViewModel` class (commit 130d021)

## Known Limits
- Error overlay shows "切换清晰度" button but doesn't actually switch source yet — just dismisses the error
