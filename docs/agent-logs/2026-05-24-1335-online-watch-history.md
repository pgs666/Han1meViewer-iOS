# Online Watch History

## User Input

Original:

```text
继续完成下一步
```

English translation:

```text
Continue completing the next step.
```

## What Changed

- Added a shared KMP online watch history feature for `user/{id}/histories`.
- Added a Ktor repository that loads online history with login cookies and deletes history items through `DELETE /user/tab-item/{videoCode}`.
- Added SwiftUI `OnlineWatchHistoryView` and `OnlineWatchHistoryViewModel`.
- Updated the Mine tab video section to expose both online history and local history.

## Why

The player work is intentionally paused, so the next useful vertical slice is another Android drawer feature that depends on login, Ktor, parsing, Swift view models, pagination, and mutation handling.

## Mistakes Or Failed Attempts

- None in this step so far.

## Verification

- Pending local KMP tests and GitHub Actions iOS build.

## Known Limits

- The online history parser reuses the existing user video list card parser because the Android parser reads the same `user-tab-item-wrapper` card structure.
- Runtime behavior still needs real-account validation on device because this endpoint requires login cookies and CSRF.
