# Agent Log: Comment Composer Keyboard and Glass

## User Input

Original:

```text
输入框的位置不对，首先就是在没有激活输入的时候位置太高，离屏幕底部太远，我希望他和tabbar的高度是一样的。然后就是激活输入后，输入框的位置达到了两倍的输入法高度以上，你搜搜应该怎么正确处理
还有，当前输入框的处理对于iPad来说是不是有问题？检查一下（我自己还没测试过，请你看看代码）
另外，当前输入框虽然有玻璃效果，但是没有弹性效果，旁边的发送按钮页也没有玻璃效果和弹性效果，请你针对iOS26继续看文档代码
```

English translation:

```text
The input field position is wrong. First, when input is inactive it is too high and too far from the bottom; I want it to match the tab bar height. Then when input is active, it rises to more than twice the keyboard height. Search how this should be handled correctly.
Also, is the current input handling a problem for iPad? Check the code, I haven't tested it myself yet.
Also, the current input field has a glass effect but no elastic effect, and the send button has neither glass nor elastic effect. Continue checking the iOS 26 docs/code.
```

## What Changed

- Removed manual bottom safe-area padding from the root comment composer so SwiftUI keyboard avoidance is not double-counted.
- Made the compact composer chrome use a 49 pt minimum height, matching the tab-bar content height expectation when the keyboard is inactive.
- Kept comment-list bottom clearance separate from the composer's actual position.
- Detected keyboard safe-area activation by comparing SwiftUI geometry safe-area bottom against the key window's container bottom inset, rather than using input focus.
- Wrapped the iOS 26 comment controls in `GlassEffectContainer`.
- Changed the input capsule to `.glassEffect(.regular.interactive(), in: Capsule())`.
- Added an iOS 26 circular interactive glass effect to the send button while preserving the fixed 42 pt hit target.

## Why

SwiftUI already treats the software keyboard as a safe-area adjustment when the view does not ignore the keyboard safe area. Manually adding the geometry bottom inset to the composer causes the focused bar to move by the keyboard height and then add the same inset again.

Focus is not a reliable keyboard-height signal on iPad because hardware keyboards and floating/split software keyboards can focus a text field without producing a full bottom keyboard safe area. The composer should stay in normal root layout and let the system keyboard safe area move it only when the system actually exposes that inset.

Apple's Liquid Glass documentation says custom components need `interactive(_:)` to get the same responsive touch and pointer reaction that standard glass buttons provide, and recommends `GlassEffectContainer` when multiple glass shapes are used together.

## Verification

- Pending local checks and GitHub Actions CI after push.
