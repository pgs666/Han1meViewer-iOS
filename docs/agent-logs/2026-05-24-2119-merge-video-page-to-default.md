# Merge Video Page To Default Branch

## User Request

中文原文：

> 把播放页修改合并到默认分支吧

English translation:

> Merge the video page changes into the default branch.

## Actions

- Confirmed the repository default branch is represented locally by `feature/ios-kmp-mvp`.
- Merged `origin/feature/swiftui-android-video-page` into `feature/ios-kmp-mvp`.
- Resolved the single conflict in `iosApp/SearchView.swift` by keeping the default branch's newer search filter badge implementation, because that branch already contains the latest fix for the badge placement issue.
- Kept the video page, fullscreen orientation, related video fallback, and home error pull-to-refresh changes from the video page branch.

## Verification

- Pending local checks and GitHub Actions build.
