# Wire Artist Subscription Button

## User Input

Original:

```text
Artist 订阅按钮 — 解析了但 UI 未接线，修好它
```

English translation:

```text
Artist subscription button: it is parsed but the UI is not wired up. Fix it.
```

## Additional User Notes

Original:

```text
代码质量（非紧急）：
- @Environment(\.presentationMode) 2 处（CloudflareChallengeView、LoginView）
- .foregroundColor() 17 处（6 个文件）
- 每个 Repository 独立 HttpClient 实例（架构优化）
```

English translation:

```text
Code quality, non-urgent:
- @Environment(\.presentationMode) in 2 places (CloudflareChallengeView, LoginView)
- .foregroundColor() in 17 places across 6 files
- Each Repository has its own HttpClient instance (architecture optimization)
```

## Changes

- Added a KMP `VideoRepository.setArtistSubscription` API.
- Implemented the `/subscribe` form POST in `KtorVideoRepository`, matching Android behavior:
  - target subscribed state sends an empty `subscribe-status`.
  - target unsubscribed state sends `"1"`.
- Exposed parsed artist subscription `userId` and `artistId` through `VideoDetailSnapshot`.
- Wired the SwiftUI artist card button to the shared `VideoFeature`.
- Added unsubscribe confirmation on iOS, matching the Android flow.
- Updated the loaded video snapshot after subscribe/unsubscribe succeeds.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only existing line-ending warnings for edited Swift/Kotlin files.
- Swift compilation still needs CI or Xcode verification.
