# Add Custom Mirror Domain

## User Input

Original:

```text
自定义镜像站可以先做，允许重启生效
```

English translation:

```text
We can implement custom mirror sites first, and it is acceptable for changes to take effect after restarting.
```

## What Changed

- Added a custom mirror editor under Settings → Network.
- Accepts a hostname with or without `https://`, normalizes the scheme and host, and removes the trailing root slash.
- Rejects non-HTTPS URLs, credentials, query parameters, fragments, and non-root paths.
- Shows the saved custom host as the selected item alongside the predefined domain choices.
- Updated `AppDomain.currentBaseURL` to accept a valid saved custom origin instead of discarding any value outside the predefined list.
- Keeps the existing restart-required behavior; the KMP environment uses the new base URL on the next launch.

## Why

All KMP repositories capture `baseUrl` when `SharedAppEnvironment` is created. Persisting a validated custom origin and applying it on the next launch provides custom mirror support without introducing runtime dependency-container replacement.

## Verification

- Confirmed predefined domain values still pass through the same normalization path.
- Confirmed custom values may omit `https://` and are persisted as normalized HTTPS origins.
- Confirmed invalid schemes, credentials, paths, queries, and fragments are rejected before persistence.
- Final Swift compilation and iOS integration are verified by GitHub Actions on macOS after push.

## Limits

- Domain changes require fully quitting and reopening the app.
- The editor validates URL structure only; it does not probe whether the mirror is online or compatible before saving.
- Plain HTTP mirrors are intentionally unsupported because the application does not allow arbitrary insecure API traffic through App Transport Security.
