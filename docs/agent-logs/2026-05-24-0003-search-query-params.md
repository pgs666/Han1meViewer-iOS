# Agent Log: Search Query Params

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
接下来完成下一步工作
```

English translation:

```text
Continue and complete the next step of work.
```

## Changes

- Adjusted `KtorSearchRepository` to only send non-empty search query parameters.

## Why

The Android Retrofit API omits null query values. The KMP Ktor implementation should preserve that behavior instead of relying on nullable parameter handling.

## Verification

- Pending rerun of local Gradle tests after this edit.

## Known Limits

- Advanced filters are still not exposed in SwiftUI.
