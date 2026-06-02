# Agent Log: Float Comment Composer

## User Input

Original:

```text
评论按钮实现依然不对：我希望它悬浮在简介/评论 view上面，检测到在评论view里面就自动出现，如果不在就自动消失，而不是把它整个放进评论区的scroll view里面。然后这个输入框我希望它能跟随输入法上边缘浮起，而不是被输入法挡住。先搜索再做
```

English translation:

```text
The comment button implementation is still wrong: I want it to float over the introduction/comments views, automatically appear when the comments view is active, and disappear when it is not. It should not be placed inside the comments scroll view. The input field should also float with the keyboard's top edge instead of being covered by the keyboard. Search first, then implement.
```

## What Changed

- Moved the main comment composer out of the comments `ScrollView`.
- Mounted the composer as a floating overlay on the introduction/comments pager container.
- The composer now appears only when the active tab is `.comments`, and disappears on `.introduction`.
- Marked the floating composer as a horizontal-pager exclusion area so input/button touches do not trigger page swipes.
- Stopped ignoring keyboard safe-area regions in inline video detail mode by switching to container-only safe-area ignoring, and only in fullscreen.
- Added interactive keyboard dismissal to the tab scroll views.
- Added a little extra bottom padding to the comments content so the floating composer does not cover the last visible comments.

## Why

Apple's SwiftUI safe-area model treats keyboard avoidance as a safe-area adjustment. The previous root-level safe-area ignore used the default safe-area regions, which can include the keyboard region. Keeping inline mode inside the keyboard-safe layout lets the floating composer move with the keyboard without manual keyboard-height observers.

The previous composer was attached to the comments `ScrollView` as a bottom inset. That made it part of the scroll view's layout instead of a layer controlled by the active pager tab.

## Verification

- `git diff --check` passed.
- `./gradlew :shared:jvmTest` passed on local Linux aarch64. Kotlin/Native remains unsupported on this host, so the iOS Swift build is verified through GitHub Actions.
