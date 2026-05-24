## User Input

Original:

```text
把结果旁边的数字改成返回到搜索历史的按钮，然后筛选按钮上的数字还是不对劲，修改它
```

English translation:

```text
Change the number next to Results into a button that returns to search history, and the number on the filter button still looks wrong. Fix it.
```

## What Changed

- Replaced the result-count text in the search results section header with a search-history button.
- Added a `showHistory()` action to the search view model to return the search screen to the history view.
- Moved the filter active-count badge outside the toolbar `Button` overlay and into an outer `ZStack` so it is not clipped by the button's liquid glass shape.

## Why

- The result count was not useful as an action surface.
- The badge was visually clipped because it was attached to the toolbar button itself.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI verification.
