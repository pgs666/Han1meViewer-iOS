# Fix: 观察者方法位置错误

## User Input

Original:
M9. AVPlayer 没监听 error / failedToPlayEndTime — 视频源失效时 iOS 黑屏没提示。

English translation:
M9. AVPlayer has no error/failedToPlayEndTime listener — when a video source fails, iOS shows a black screen with no feedback.

## What Changed
- Moved `observePlayerItemErrors()` and `removePlayerObservers()` methods from after `VideoMyListRow` struct back inside `VideoDetailViewModel` class
- These methods were incorrectly placed outside the class due to a string replacement ordering issue

## Why Changed
- The initial M9 implementation used Python string replacement to insert methods before `private extension CMTime`
- The replacement pattern matched incorrectly, placing the methods after `VideoMyListRow` struct instead of inside the class
- This caused a Swift compilation error: "Extraneous '}' at top level"

## Mistakes
- The Python string replacement approach was fragile — it replaced text that appeared in multiple contexts
- Should have verified the file structure after the initial edit

## Verification
- CI passed on the fix commit (26435784946 → completed success)

## Known Limits
- None
