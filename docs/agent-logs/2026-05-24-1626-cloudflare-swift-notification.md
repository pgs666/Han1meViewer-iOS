## User Input

Original:

```text
做 完整 WKWebView 自动过挑战
```

English translation:

```text
Implement full automatic WKWebView Cloudflare challenge handling.
```

## What Changed

- Added a Swift notification helper for requesting Cloudflare challenge presentation from anywhere in the app.

## Why

- Existing ViewModels already funnel errors through `ErrorMessage.userFriendly`. A notification keeps the challenge trigger centralized without modifying every ViewModel.

## Mistakes Or Failed Attempts

- No failed attempt in this step.

## Verification

- Pending iOS CI verification.

## Known Limits

- This notification helper only requests presentation; the WKWebView implementation is in a separate file.
