## User Input

Original:

```text
这个界面顶上的筛选按钮问题还是很多
```

English translation:

```text
The filter button at the top of this screen still has many problems.
```

## Change

- Reworked the search screen toolbar filter button.
- Removed the outer `ZStack` and extra top/trailing padding that were expanding the system toolbar button's visual bounds.
- Moved the active filter count into a small overlay on the filter icon itself.
- Added a small reusable SwiftUI badge view for the count.

## Why

- On iOS 26, the system toolbar/liquid-glass button uses the full toolbar item bounds. The previous padding made the button render as an oversized floating circle.
- The badge should visually sit on the icon, without changing the button's system size.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI after commit and push.
