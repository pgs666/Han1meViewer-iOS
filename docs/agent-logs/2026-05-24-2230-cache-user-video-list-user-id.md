# Cache User Video List User ID

## User Input

Original:

```text
之前提到的 Bug（未修复）

3. userId 每次请求首页获取 — UserVideoListFeature 每次都解析首页 HTML
```

English translation:

```text
Previously mentioned bugs that are not fixed yet:

3. The userId is fetched from the home page every time. UserVideoListFeature parses the home page HTML each time.
```

## Changes

- Updated `UserVideoListFeature` to reuse its cached `currentUserId` when available.
- Added a shared resolver used by both list loading and item removal.
- Kept the homepage fallback for the first load or when no cached user id exists.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only an existing line-ending warning for `UserVideoListFeature.kt`.
