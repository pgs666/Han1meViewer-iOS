# Agent Log: Switch CI To Xcode 26

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
我要求现在就换xcode
```

English translation:

```text
I require switching Xcode now.
```

## Changes

- Changed both GitHub Actions workflows from `macos-15` to `macos-26`.
- Added an explicit `xcode-select` step for `/Applications/Xcode_26.2.app` in:
  - `.github/workflows/ios-app-build.yml`
  - `.github/workflows/kmp-ios-build.yml`

## Why

The search button work should be validated against the current iOS 26 SDK instead of treating Liquid Glass as only a future fallback. Keeping the runner and Xcode explicit also makes CI failures clearer if GitHub changes the default Xcode on the image.

## Verification

- Pending push and GitHub Actions verification.

## Known Limits

- The deployment target remains iOS 15.0. This means iOS 26-only UI APIs must still be guarded or isolated so the app can launch on iOS 15 devices.
