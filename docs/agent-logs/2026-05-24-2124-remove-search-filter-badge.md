# Remove Search Filter Badge

## User Request

中文原文：

> 新实现依然有问题，要不按照我说的来：在没有筛选和标签的时候使用默认的白色/黑色，有的时候调成主题色，这个数字没必要保留了

English translation:

> The new implementation still has problems. Let's do it my way: when there are no filters or tags, use the default white/black color; when there are filters, switch to the theme color. The number is unnecessary.

## Changes

- Removed the numeric badge from the search filter toolbar button.
- Kept the native SwiftUI toolbar button.
- Set the filter icon to `Color.primary` when no filter is active, so it follows the system white/black appearance.
- Set the filter icon and button tint to `Color.accentColor` when any filter is active.

## Verification

- Pending local checks and GitHub Actions build.
