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

- Created branch `feature/swiftui-android-video-page`.
- Started exposing Android playback-page data through the KMP video snapshot:
  - artist
  - favorite/watch-later state
  - original comic link
  - full tags
  - playlist videos
  - my-list entries
- Extended the KMP HTML parser to extract the missing playback-page fields from the video page.

## Why

- The SwiftUI page cannot visually match the Android playback page unless the shared layer exposes the same content groups used by Android.
- This branch is isolated because the requested playback page redesign is larger than the ongoing MVP branch work.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI after commit and push.
