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

## Change

- Removed a force unwrap from the home video card artist label.
- Kept the fallback artist text local to the SwiftUI row model rendering.

## Why

- The home card should render safely even when parsed video metadata does not include an artist.
- This is a small cleanup before committing the larger home banner and horizontal section implementation.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI after the full home change is committed.
