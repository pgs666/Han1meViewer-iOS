## User Input

Original:

```text
创建分支，然后在此分支播放页完全照搬安卓版本的界面，但是完全用swiftUI实现，不使用自定义组件
```

English translation:

```text
Create a branch, then on this branch make the playback page fully copy the Android version's interface, but implement it completely with SwiftUI and do not use custom components.
```

## Change

- Replaced `ContentUnavailableView` usage in the rewritten video page with plain SwiftUI `VStack` empty/error states.

## Why

- The project deployment target is iOS 15, and `ContentUnavailableView` is not available there.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI after commit and push.
