# Search History Plan

## User Input

Original:

```text
继续实现
```

English translation:

```text
Continue implementing.
```

## What I Plan To Change

- Use the existing SQLDelight `search_history` table.
- Add a shared KMP `SearchHistoryStore`.
- Inject the store into `SearchFeature`.
- Record successful first-page keyword searches.
- Expose recent search keywords through `SearchFeature`.
- Update the Swift search screen idle state to show recent searches and let users tap one to search again.

## Why

The search tab already has real network search and pagination. Search history is the next useful local feature and proves another SQLDelight table without expanding scope into a larger account feature.

## Verification Planned

- Run `./gradlew :shared:jvmTest`.
- Push and wait for GitHub Actions `iOS App Build`.

## Known Limits

- This first version does not deduplicate rows at the database level. The feature will present unique recent keywords in the UI.
