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

- Tightened shared Ktor Cloudflare challenge detection.
- `isCloudflareChallenge()` now only accepts `cf-mitigated: challenge`.

## Why

- Normal Cloudflare-served responses can include headers such as `cf-ray` or `cf-cache-status`.
- Treating any `cf-*` header as a challenge can misclassify ordinary 403 responses and show the challenge UI at the wrong time.

## Mistakes Or Failed Attempts

- No failed implementation attempt in this step.

## Verification

- Pending Gradle and iOS CI verification after all requested fixes are complete.

## Known Limits

- This intentionally does not inspect HTML challenge bodies yet. It relies on the explicit Cloudflare mitigation header.
