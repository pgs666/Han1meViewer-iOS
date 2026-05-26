# 登录页顶部刷新按钮使用自适应文字色

## User Input

Original:
现在屏幕顶部的刷新按钮颜色不对，我希望它使用的颜色和文字一样是自适应的而不是强调色

English translation:
The refresh button at the top of the screen currently has the wrong color. I want it to use the same adaptive color as text instead of the accent color.

## What Changed
- `LoginView.swift` now sets the login page refresh icon foreground style to `.primary`.
- The refresh button also sets `.tint(.primary)` so toolbar rendering does not inherit the global red accent tint.

## Why Changed
- The app applies a global red tint, so toolbar buttons without an explicit tint can render as accent red.
- `.primary` follows the system text color and adapts between light and dark mode.

## Verification
- GitHub Actions `iOS App Build` passed for run `26445148186`.
- CI steps included shared JVM tests, Xcode project generation, unsigned device app build, IPA packaging, and artifact upload.
- No local Swift build is available in this Linux environment.

## Mistakes
- None in this fix.

## Known Limits
- This fix targets the login WebView refresh button only.
