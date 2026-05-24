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

- Restored the `HttpHeaders` import in `Han1meHttpClient.kt`.

## Why

- Local `:shared:jvmTest` failed because `setCookieHeaders()` still uses `HttpHeaders.SetCookie`.
- The import was accidentally removed while tightening Cloudflare challenge detection.

## Mistakes Or Failed Attempts

- Failed verification:

```text
./gradlew :shared:jvmTest
Unresolved reference 'HttpHeaders'
```

## Verification

- Pending rerun after this fix.

## Known Limits

- No behavior change beyond restoring compilation.
