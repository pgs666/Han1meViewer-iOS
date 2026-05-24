## User Input

Original:

```text
现在我要求你实现：Banner和多个分类横向列表，要求是完全使用swiftui的原生组件，不自己瞎实现，功能和样式都参考安卓版

点击更多的时候别忘了不加入搜索历史
```

English translation:

```text
Now I require you to implement: Banner and multiple category horizontal lists. It must completely use native SwiftUI components, do not randomly custom-build things, and both function and style should reference the Android version.

When tapping More, don't forget that it should not be added to search history.
```

## Plan

- Replace the current iOS home `List` layout with native SwiftUI `ScrollView` and horizontal `LazyHStack` sections.
- Keep the Android structure: top banner, then multiple category rows with title, "more" action, and horizontal video cards.
- Extend KMP home video snapshots with metadata already available in parsed `HanimeInfo`: duration, views, upload time, artist, and reviews.
- Make the "more" action open the Search tab without executing a search, so it does not add anything to search history.
- Avoid player changes and avoid implementing announcements in this slice.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI verification.
