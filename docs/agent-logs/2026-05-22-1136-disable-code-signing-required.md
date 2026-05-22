# Agent Log: Disable Code Signing Required

Time: 2026-05-22 11:36 +08:00

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

- Added `CODE_SIGNING_REQUIRED=NO` to the simulator and device Xcode build commands.
- Added `CODE_SIGN_IDENTITY=""` to the simulator and device Xcode build commands.

## Why

Device builds can still fail signing checks even when `CODE_SIGNING_ALLOWED=NO`. These extra build settings make the CI intent explicit: compile and package an unsigned app bundle.

## Verification

Pending GitHub Actions/macOS verification after push.

## Known Limits

- The output remains unsigned. Installing on real hardware still requires a separate signing/sideloading path.
