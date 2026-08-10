# Organize iOS Application Sources

## User Input

Original:

```text
帮我开始整理吧，这个仓库目前的测试方案是直接推到GitHub等待ci编译完成，你也这么做
```

English translation:

```text
Please start organizing it. This repository currently tests by pushing directly to GitHub and waiting for CI to finish compiling; do the same.
```

## What Changed

- Reorganized the flat `iosApp` Swift source directory into `App`, `Core`, `Features`, and `Player` ownership areas.
- Kept `Info.plist`, entitlements, localization, and asset catalogs at the `iosApp` root so existing build-setting paths remain stable.
- Split download presentation models and the URLSession delegate out of `DownloadManager.swift`.
- Updated the architecture document to describe the new layout.

## Why

The application had 64 Swift files in one directory and several unrelated infrastructure and feature concerns were mixed together. The new layout makes ownership visible without changing the KMP/SwiftUI architecture or runtime behavior.

## Mistakes Or Failed Attempts

- Local XcodeGen generation could not be run because `xcodegen` is not installed in the current Linux environment.

## Verification

- Confirmed `project.yml` recursively includes the entire `iosApp` source tree.
- Kept all explicitly referenced build resources at their existing paths.
- Checked for stale source-path references outside historical agent logs.
- Ran `git diff --check` and checked that each extracted download type has exactly one declaration.
- The authoritative macOS/Xcode build will run in the `iOS App Build` GitHub Actions workflow after this commit is pushed.

## Known Limits And Follow-Up

- This is the first, low-risk organization pass. Large files such as `KSPlayerView.swift`, `VideoDetailView.swift`, and `VideoDetailViewModel.swift` still need focused decomposition in later commits.
- No functional bugs were intentionally changed in this organization-only commit.
