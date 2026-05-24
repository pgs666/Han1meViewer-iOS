# Search Pagination Implementation

## User Input

Original:

```text
开始做吧
```

English translation:

```text
Start doing it.
```

## What Changed

- Added `page` and `hasNext` metadata to the KMP `SearchSnapshot`.
- Updated `SearchViewModel` to track the active keyword, loaded page, next-page availability, and load-more errors.
- Added automatic load-more behavior when the last search result row appears.
- Added a search footer for loading, retry, and end-of-results states.

## Why

The KMP repository already returns `PageResult.hasNext`, but the Swift UI discarded it and only showed the first page. This connects the existing pagination data to the actual iOS search screen.

## Mistakes Or Failed Attempts

- The first patch against `SearchView.swift` used mojibake text from PowerShell output as context and failed. I retried using stable structural Swift lines instead.

## Verification Performed

- Ran `./gradlew :shared:jvmTest`.
- Result: passed.

## Known Limits

- iOS compilation still needs GitHub Actions because this environment is Windows.
- Pagination is keyword-only for now; advanced Android search filters remain future porting work.
