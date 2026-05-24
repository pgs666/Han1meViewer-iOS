# Following Feature Implementation

## User Input

Original:

```text
继续下一步
```

English translation:

```text
Continue to the next step.
```

## What Changed

- Added shared KMP models for subscriptions:
  - `MySubscriptions`
  - `SubscriptionItem`
  - `SubscriptionVideoItem`
- Added `HtmlParser.parseSubscriptions` and implemented it in `KsoupHtmlParser` using the Android parser selectors as reference.
- Added `FollowingRepository` and `KtorFollowingRepository` for `/subscriptions`.
- Added `FollowingFeature` and Swift-friendly snapshot accessors.
- Exposed `followingFeature()` from `SharedAppEnvironment`.
- Replaced the placeholder SwiftUI `FollowingView` with a real data-driven screen.
- Added `FollowingViewModel` with initial load, pagination, retry, and load-more error handling.
- Wired the app tab to `FollowingView(environment:)`.

## Why

The `关注` tab was still static placeholder UI. Android already has a working subscriptions page implementation, and this feature fits the current vertical-slice pattern used by Home, Search, and Video.

## Mistakes Or Failed Attempts

- A patch against `Han1meViewerApp.swift` initially failed because PowerShell displayed Chinese text as mojibake in the context. I retried the patch using only the stable `FollowingView()` line.

## Verification Planned

- Run `./gradlew :shared:jvmTest`.
- Push and wait for GitHub Actions `iOS App Build`.

## Known Limits

- This adds read-only subscriptions. Follow/unfollow actions are still future work.
- Logged-out behavior currently depends on the endpoint response and parser error. A later pass can route users directly to Web login from this tab.
