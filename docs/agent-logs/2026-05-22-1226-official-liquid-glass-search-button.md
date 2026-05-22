# Agent Log: Official Liquid Glass Search Button

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
不是未来sdk，这里是文档https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes

我要求现在就换xcode
```

English translation:

```text
It is not a future SDK; here is the documentation: https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes

I require switching Xcode now.
```

## Changes

- Updated `iosApp/SearchView.swift` so the standalone search button uses Apple's official SwiftUI `.glassProminent` button style on iOS 26 and later.
- Kept the existing material-based fallback for iOS 15 through iOS 25.

## Why

The project now targets the iOS 26 SDK in CI, so the search button should use the real Liquid Glass API where the OS supports it. The app still has an iOS 15 deployment target, so the official API must remain availability-gated.

## Verification

- Pending local status check and GitHub Actions build after push.

## Known Limits

- The fallback style is still used on iOS versions below 26.
