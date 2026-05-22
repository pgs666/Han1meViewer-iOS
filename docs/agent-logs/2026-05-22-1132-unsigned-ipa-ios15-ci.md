# Agent Log: Unsigned IPA And iOS 15 CI

Time: 2026-05-22 11:32 +08:00

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

- Changed the XcodeGen deployment target from iOS 17.0 to iOS 15.0.
- Added a CI device build for `generic/platform=iOS` using `CODE_SIGNING_ALLOWED=NO`.
- Added an unsigned IPA packaging step that copies `Han1meViewer.app` into `Payload/` and zips it as `Han1meViewer-unsigned.ipa`.
- Added an artifact upload step named `Han1meViewer-unsigned-ipa`.

## Why

The simulator build proves Swift/KMP linking, but real-device testing needs an `iphoneos` app bundle. Packaging the unsigned `.app` as an `.ipa` makes it easy to download from GitHub Actions and use with a separate signing or sideloading flow.

## Verification

Pending:

```powershell
xcodegen generate
```

Full device build and IPA packaging require GitHub Actions/macOS.

## Known Limits

- A truly unsigned IPA generally cannot be installed directly on a normal iPhone without a separate signing/sideloading tool or provisioning flow.
- CI still keeps the simulator build as the primary app compile check before packaging the device artifact.
