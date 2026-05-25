# CI, README, Refresh, And Retry Fixes

Time: 2026-05-25 17:04:18 +08:00

## User Input

Original:

```text
5   │ README JDK 版本错误      │ README.md:93                                 │ 写的 JDK 17+，实际 Gradle 9.4.1 │
  │     │                          │                                              │  需要 JDK 21+                  7   │ CI Gradle 构建重复执行   │ ios-app-build.yml:39-63                      │ 两次 xcodebuild 各触发一次 KMP  │
  │     │                          │                                              │ 框架构建                        │
  ├─────┼──────────────────────────┼──────────────────────────────────────────────┼─────────────────────────────────┤
  │ 8   │ CI 无测试步骤            │ ios-app-build.yml                            │ 只构建不测试           ─┼──────────────────────────┼──────────────────────────────────────────────┼─────────────────────────────────┤
  │ 11  │ 多处缺少下拉刷新         │ Following/WatchHistory/OnlineHistory/Comment │ 只有手动刷新按钮，无            │
  │     │                          │
```

```text
│ 12  │ 错误状态无重试按钮       │ HomeView/VideoDetailView                     │ 其他页面都有重试，这两个没有    │
```

English translation:

```text
5. README has the wrong JDK version. README.md says JDK 17+, but Gradle 9.4.1 actually needs JDK 21+.
7. CI Gradle build runs redundantly. ios-app-build.yml has two xcodebuild calls and each triggers KMP framework build.
8. CI has no test step; it only builds.
11. Multiple screens lack pull-to-refresh: Following, WatchHistory, OnlineHistory, Comment.
12. Error states lack retry buttons: HomeView and VideoDetailView, while other pages have retry.
```

## Changes

- Updated README development requirements from JDK 17+ to JDK 21+.
- Added `./gradlew :shared:jvmTest --no-daemon` to the iOS app CI workflow.
- Removed the separate simulator `xcodebuild` step so CI only performs one app build before IPA packaging.
- Added pull-to-refresh to:
  - `FollowingView`
  - `WatchHistoryView`
  - `OnlineWatchHistoryView`
  - `CommentView`
- Added retry buttons to failed states in:
  - `HomeView`
  - `VideoDetailView`

## Verification

- Static search confirmed README now documents JDK 21+.
- Static search confirmed CI includes the shared JVM test step.
- Static search confirmed the extra simulator `xcodebuild` step was removed.
- Static search confirmed the requested screens now have `.refreshable`.
- Static search confirmed `HomeView` and `VideoDetailView` failed states now include retry buttons.

## Follow-up

- Push to GitHub and watch the CI run to verify the workflow change on macOS.
