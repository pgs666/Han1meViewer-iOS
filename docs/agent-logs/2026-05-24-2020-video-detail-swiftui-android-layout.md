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

- Replaced the simple iOS video detail `List` with a SwiftUI page structured after Android:
  - top embedded player area
  - quality segmented picker
  - introduction/comments segmented tabs
  - artist card
  - title and metadata
  - expandable description
  - horizontal action buttons
  - tag grid
  - playlist horizontal list
  - related video grid
- Updated `VideoDetailViewModel` to bridge the new KMP snapshot fields into Swift structs.

## Notes

- The UI uses SwiftUI-native views such as `ScrollView`, `LazyVStack`, `LazyHStack`, `LazyVGrid`, `Picker`, `Button`, `NavigationLink`, `AsyncImage`, and `VideoPlayer`.
- The Android quick check-in action is intentionally not included because the standing project rule says not to implement check-in.
- Comments are represented as a tab placeholder because the comment repository and parser are not migrated in the iOS shared layer yet.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI after commit and push.
