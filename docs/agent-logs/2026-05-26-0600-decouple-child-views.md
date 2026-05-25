# Decouple Child Views from ViewModel (Q-11)

Date: 2026-05-26 06:00:00 +08:00

## What Changed

Refactored `ActionButtonRow` and `AndroidStyleIntroduction` to accept data + callbacks instead of `@ObservedObject var viewModel: VideoDetailViewModel`.

### ActionButtonRow
- Replaced `@ObservedObject var viewModel` with explicit closures:
  - `onToggleFavorite: () -> Void`
  - `onToggleWatchLater: () -> Void`
  - `onSetMyListItem: (VideoMyListItemSnapshot, Bool) -> Void`
  - `onShowMessage: (String) -> Void`

### AndroidStyleIntroduction
- Replaced `@ObservedObject var viewModel` with:
  - `isArtistActionRunning: Bool`
  - `onToggleArtistSubscription: () -> Void`
  - Plus the same ActionButtonRow callbacks passed through

### AndroidStylePlayerHeader
- Kept `@ObservedObject var viewModel` — video player has inherent tight coupling with playback state (player instance, source selection, rate control, fullscreen). Decoupling would require 8+ parameters with no readability benefit.

## Why

Q-11 identified that child views directly mutate the ViewModel via `@ObservedObject`. Replacing with explicit data + callbacks makes the data flow visible and reduces coupling.

## Verification

- CI build passed (JVM tests + iOS device build + IPA packaging)
- No behavior change — same actions triggered, same data displayed

## Known Limits

- `AndroidStylePlayerHeader` still uses ViewModel — acceptable trade-off for video player complexity
- `VideoDetailView` (main view) still owns and passes the ViewModel — this is correct ownership

## User Input

Original:

```
目前文件夹里有两个库，一个是原版，一个是iOS移植版，review结果在review文件夹里面，我需要你创建新的分支，基于review结果进行优化（只需要修复bug和性能问题还有代码质量问题，不需要添加新功能）
```

English translation:

```
There are two libraries in the folder — the original and an iOS port. Review results are in the review folder. I need you to create a new branch and optimize based on the review results (only fix bugs, performance issues, and code quality issues — no new features).
```
