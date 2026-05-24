## User Input

Original:

```text
另外我希望让搜索的时候可以搜索空的关键词，然后在搜索历史显示筛选的标签内容（以小字形式），如果是空关键词的情况下，让标签显示 和关键词一样大
```

English translation:

```text
Also, I want search to allow an empty keyword. In search history, show the selected filter tag content in smaller text. If the keyword is empty, show the tags at the same size as the keyword.
```

## What Changed

- Added support for empty-keyword searches.
- Added structured search history rows containing both keyword and filter summary.
- Stored the filter summary in the existing search history column using a versioned encoded value instead of changing the SQL table shape.

## Why

- Filter-only search is a normal workflow now that the search page has a full filter sheet.
- History needs to preserve what was searched, not only the typed keyword.

## Mistakes Or Failed Attempts

- Initial implementation changed the `search_history` SQL table by adding `filter_summary`.
- I reverted that schema change before committing because it could require a database migration on already installed test builds. The final implementation keeps the existing table shape.

## Verification

- `./gradlew :shared:jvmTest` passed after the schema-preserving adjustment.
- Pending iOS CI verification.

## Known Limits

- Existing plain keyword history rows continue to display as keyword-only rows.
- History rows display filter summaries, but they do not yet restore the exact filter selections when tapped.
