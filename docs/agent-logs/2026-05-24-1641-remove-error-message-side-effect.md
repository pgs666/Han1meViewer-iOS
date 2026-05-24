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

- Removed Cloudflare presentation side effects from `ErrorMessage.userFriendly`.
- Added an explicit Cloudflare trigger helper and called it from ViewModel catch paths before formatting errors.

## Why

- Error formatting should be pure. Re-formatting the same error in multiple places should not repeatedly present WKWebView sheets.
- Cloudflare presentation is UI behavior and belongs in the error handling layer around ViewModel state updates.

## Mistakes Or Failed Attempts

- No failed implementation attempt in this step.

## Verification

- Pending Gradle and iOS CI verification.

## Known Limits

- The detection still uses Swift's visible error description because Kotlin/Native exceptions cross into Swift as generic errors. The side effect is now explicit at call sites.
