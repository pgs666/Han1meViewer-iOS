# Following Feature Plan

## User Input

Original:

```text
继续下一步
```

English translation:

```text
Continue to the next step.
```

## What I Plan To Change

- Port the Android subscriptions page as the next vertical feature slice for the iOS `关注` tab.
- Add shared KMP subscription models and parser support for `/subscriptions`.
- Add a Ktor repository and `FollowingFeature` using the existing session cookie bridge.
- Expose the feature through `SharedAppEnvironment`.
- Replace the Swift placeholder `FollowingView` with a real ViewModel-driven UI that displays subscribed artists and updated videos.

## Why

The app already has real home, search, video, login, and session plumbing. The `关注` tab is still placeholder UI, and Android has a clear `getMySubscriptions` implementation that maps well to the current KMP repository pattern.

## Verification Planned

- Run `./gradlew :shared:jvmTest`.
- Push and wait for GitHub Actions `iOS App Build` if Swift/KMP integration changes compile locally enough to reach CI.

## Known Limits

- This slice will read subscriptions only. Subscribe/unsubscribe actions from video detail can be ported later.
- If the endpoint returns the login page while logged out, the first version will surface a normal error or empty state instead of opening login automatically.
