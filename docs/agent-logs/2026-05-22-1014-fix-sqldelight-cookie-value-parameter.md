# Agent Log: Fix SQLDelight Cookie Value Parameter

Time: 2026-05-22 10:14 +08:00

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## What Went Wrong

The first implementation of `SqlDelightSessionStore` called `sessionCookieQueries.upsert` with a named parameter `value`.

SQLDelight generated that parameter as `value_`, likely to avoid a naming conflict.

The compile error was:

```text
No parameter with name 'value' found.
No value passed for parameter 'value_'.
```

## What I Changed

Updated the call site:

```kotlin
value_ = cookie.value
```

## Verification

Verification is run immediately after this change.
