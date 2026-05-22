# Agent Log: Fix iOS 15 SwiftUI APIs

Time: 2026-05-22 11:43 +08:00

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## User Input

Original:

```text
ci编译输出无签名的ipa文件方便我进行真机测试，然后支持的最低ios版本设置到ios15
```

English translation:

```text
Make CI output an unsigned IPA file so I can test on a real device, and set the minimum supported iOS version to iOS 15.
```

## What I Changed

- Replaced `NavigationStack` with `NavigationView` in the current SwiftUI views.
- Added `.navigationViewStyle(.stack)` so iPad-style split navigation does not alter the simple MVP layout.
- Replaced `ContentUnavailableView` with an iOS 15-compatible `VStack` error view.

## Why

After lowering the deployment target to iOS 15, GitHub Actions failed because:

- `NavigationStack` requires iOS 16.
- `ContentUnavailableView` requires iOS 17.

The app target must avoid these APIs if it claims iOS 15 support.

## Mistakes Or Failures

- The first iOS 15 change only adjusted the deployment target and workflow. CI then correctly exposed incompatible SwiftUI APIs.

## Verification

Failed CI run that exposed the issue:

```text
iOS App Build 26266147314
```

Pending verification after the fix is pushed.

## Known Limits

- `NavigationView` is older and less flexible than `NavigationStack`, but it is appropriate for the current MVP placeholder navigation and iOS 15 support.
