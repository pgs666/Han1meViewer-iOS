# 稳定登录页刷新按钮自适应颜色

## User Input

Original:
现在在加载完之前是黑色，加载完之后就变回强调色了，为什么

English translation:
Now it is black before loading finishes, but after loading finishes it changes back to the accent color. Why?

## What Changed
- `LoginView.swift` now renders the refresh SF Symbol as a template image with `.foregroundColor(.primary)`.
- The toolbar refresh button now uses `.buttonStyle(.plain)` in addition to `.tint(.primary)`.

## Why Changed
- Toolbar buttons are bridged through UIKit navigation bar button rendering.
- After the WebView finishes loading and SwiftUI/NavigationBar updates, UIKit can re-apply the app-wide red tint to normal toolbar buttons.
- A plain button plus explicit primary template rendering avoids the toolbar button being recolored by the global accent tint.

## Verification
- Pending CI after push.
- No local Swift build is available in this Linux environment.

## Mistakes
- The previous fix set `.foregroundStyle(.primary)` and `.tint(.primary)`, but that was not stable across toolbar re-rendering after WebView load completion.

## Known Limits
- This fix targets the login WebView refresh button only.
