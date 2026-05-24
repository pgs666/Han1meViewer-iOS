## User Input

Original:

```text
修改搜索页，点进搜索页如果没有搜索历史默认显示空白占位符，如果有就显示搜索历史
```

English translation:

```text
Modify the search page: when entering the search page, show a blank placeholder by default if there is no search history; if there is search history, show the search history.
```

## What Changed

- Reworked the search idle state.
- Removed the default browse/category card grid from the search page.
- When there is no search history, the page now shows a simple empty placeholder.
- When search history exists, the page shows only the history list and clear button.
- Removed the unused browse card model/view code.
- Removed the now-unused idle filter summary view.

## Why

- The requested default search page behavior is history-first, not category browsing.

## Mistakes Or Failed Attempts

- The first `apply_patch` attempts could not match the existing block reliably because the terminal initially displayed the file with the wrong encoding.
- A line-range mechanical replacement corrupted the file encoding. I restored `iosApp/SearchView.swift` before committing and then applied the final change with `apply_patch` using the correct UTF-8 text.

## Verification

- Pending local and CI verification.

## Known Limits

- This does not change search results, filter behavior, or history storage.
