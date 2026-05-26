# 替换登录页刷新 Toolbar Button 避免强调色回流

## User Input

Original:
没变化啊

English translation:
There is no change.

## What Changed
- Replaced the login toolbar refresh `Button` with a custom `Image` toolbar item using `onTapGesture`.
- The custom toolbar item uses `.foregroundStyle(.primary)` and a 44x44 hit target.
- Accessibility keeps the refresh label and button trait.

## Why Changed
- The previous fix still used SwiftUI `Button` inside a navigation toolbar.
- Navigation toolbar buttons are bridged to UIKit bar button rendering and can re-apply the app-wide red tint after WebView/navigation state updates.
- A custom non-Button toolbar view avoids the default toolbar button tint pipeline while keeping the same tap behavior.

## Verification
- GitHub Actions `iOS App Build` passed for run `26446342737`.
- CI steps included shared JVM tests, Xcode project generation, unsigned device app build, IPA packaging, and artifact upload.
- No local Swift build is available in this Linux environment.

## Mistakes
- The previous button-level `.tint(.primary)` and plain style did not override UIKit toolbar retinting in the runtime state reported by the user.

## Known Limits
- This fix targets the login WebView refresh toolbar item only.
