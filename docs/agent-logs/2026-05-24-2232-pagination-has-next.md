# Fix Pagination Has Next Detection

## User Input

Original:

```text
之前提到的 Bug（未修复）

4. 分页 hasNext 多发一次请求
```

English translation:

```text
Previously mentioned bugs that are not fixed yet:

4. Pagination hasNext sends one extra request.
```

## Changes

- Replaced item-count based `hasNext` detection with pagination max-page detection.
- Applied the fix to search results, user video lists, and user playlist lists.
- Treated pages without pagination markup as single-page results.
- Added parser tests for paginated and non-paginated search HTML.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only existing line-ending warnings for edited Kotlin test/parser files.
