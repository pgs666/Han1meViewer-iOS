## User Input

Original:

```text
先做123吧
```

English translation:

```text
Do items 1, 2, and 3 first.
```

## What Changed

- Loaded `brands.json` into `SearchOptionCatalog`.
- Added selected brands to `SearchFilterState`.
- Added a brand picker section to the SwiftUI search filter sheet.
- Passed selected brands to `SearchFeature.searchAdvanced`.

## Why

- The repository and shared search model already supported `brands[]`, but Swift always passed an empty string and never exposed brand selection in the filter UI.

## Mistakes Or Failed Attempts

- No failed implementation attempt in this step.

## Verification

- Pending Gradle and iOS CI verification.

## Known Limits

- Brands are shown as multi-select chips in one section. This is functional but may need search-within-brands later because the list is long.
