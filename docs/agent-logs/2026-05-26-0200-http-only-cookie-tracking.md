# Agent Log: HttpOnly Cookie Tracking

Time: 2026-05-26 02:00:00 +08:00

Repository: `/home/pgs/Project/Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## User Input

Original:

```text
修复上面你觉得有价值的问题
```

English translation:

```text
Fix the issues above that you think are valuable.
```

## What Changed

- Added `httpOnly` to the shared `SessionCookie` model.
- Persisted the flag in the SQLDelight `session_cookie` table.
- Added migration `3.sqm` for existing databases.
- Parsed the `HttpOnly` attribute from `Set-Cookie` headers.
- Extended parser coverage to assert `HttpOnly` is retained.

## Why

The review identified that imported/stored cookies discarded the `HttpOnly` attribute. Preserving it keeps cookie metadata faithful to server responses and avoids losing security-relevant state during KMP session handling.

## Verification

Planned verification for this change:

- Run Gradle shared JVM tests locally.
- Push the code change and wait for the iOS app build workflow.

## Known Limits And Follow-up

- Cookies imported from a plain `Cookie` header cannot reconstruct `HttpOnly`, because that attribute is only present in `Set-Cookie` metadata.
