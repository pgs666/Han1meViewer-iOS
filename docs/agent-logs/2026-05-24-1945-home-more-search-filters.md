## User Input

Original:

```text
点击更多之后得接筛选参数
```

English translation:

```text
After tapping More, it needs to pass filter parameters.
```

## Change

- Added a one-shot `SearchLaunchRequest` from Home to Search.
- Made each Home section "更多" button open Search with the matching section filter:
  - latest release / latest upload / watching now map to sort options.
  - genre sections map to genre filters.
- Added a `recordHistory` flag to shared `SearchFeature.searchAdvanced`.
- Home "更多" searches with `recordHistory: false`, so it applies filters without adding a search history entry.

## Why

- The More action should behave like Android category navigation, not just switch tabs.
- It should not pollute search history because the user did not manually search.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI after commit and push.
