# Agent Log: Fix IPA Derived Data Path

Time: 2026-05-22 11:34 +08:00

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

- Added `-derivedDataPath build` to both Xcode build commands in the iOS app workflow.

## Why

The IPA packaging step expects the device `.app` at `build/Build/Products/Debug-iphoneos/Han1meViewer.app`. Without an explicit derived data path, Xcode may put the app under the default user DerivedData directory, causing the packaging step to fail.

## Mistakes Or Failures

- The first workflow edit added IPA packaging but did not pin Xcode's derived data output path.

## Verification

Pending GitHub Actions/macOS verification after push.

## Known Limits

- This only fixes the artifact path. It does not make the unsigned IPA directly installable without a separate signing or sideloading flow.
