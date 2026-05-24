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

- Added an environment entry for constructing `CloudflareFeature`.

## Why

- SwiftUI views should receive Cloudflare handling through the same shared app environment as login, home, search, and video features.

## Mistakes Or Failed Attempts

- No failed attempt in this step.

## Verification

- Pending Gradle and iOS CI verification.

## Known Limits

- This only wires construction; presentation is handled by the Swift app layer.
