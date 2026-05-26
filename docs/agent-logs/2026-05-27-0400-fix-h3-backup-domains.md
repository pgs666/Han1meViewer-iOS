# Fix H3: Backup domains infrastructure

Date: 2026-05-27 04:00 +08:00
Branch: fix/review-bugs-performance-quality
Commits: 788f785, 268704d, 00b7079

## User Input

Original:

```text
也一并提交
```

English translation:

```text
Submit those as well.
```

(Context: User asked to fix and commit all remaining valuable review items including H3.)

## What Changed

- `HanimeNetworkDefaults.kt`: Added `BACKUP_DOMAINS` and `BACKUP_HOSTNAMES` lists with 4 domains matching Android `HanimeConstants`.
- `SharedAppEnvironment.kt`: Added `baseUrl` parameter to constructor, passed to all repositories.
- `Han1meViewerApp.swift`: Passes `baseUrl: "https://hanime1.me"` explicitly (KMP default params don't work from Swift for Native targets).

## Why

Android has `HanimeConstants.HANIME_HOSTNAME` and `HANIME_URL` arrays for backup domains. The iOS version was hardcoded to `https://hanime1.me` only. This infrastructure enables future domain switching in settings UI.

## Mistakes / Failed Attempts

1. First attempt used `HanimeNetworkDefaults.DEFAULT_BASE_URL` as default value — KMP default params referencing other objects don't translate to Swift. Fixed by using a string literal.
2. String literal default still didn't work from Swift — KMP constructor default params are not exposed to Swift/Native. Fixed by passing explicit value in Swift call site.

## Verification

- Local JVM test: `:shared:jvmTest` — BUILD SUCCESSFUL
- CI run `26461096728` — success (after 3 fix attempts)

## Known Limits / Follow-up

- iOS settings UI for domain switching not implemented (P1-D4).
- The `baseUrl` parameter is passed at initialization time; dynamic switching requires recreating `SharedAppEnvironment`.
