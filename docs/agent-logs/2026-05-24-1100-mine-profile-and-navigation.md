## User Input

Original:

```text
接下来先不要做播放器相关的修改了，我准备最后完全重构它，现在先做其他的东西
```

English translation:

```text
Do not make player-related changes for now. I plan to completely refactor it at the end, so work on other things first.
```

## Changes

- Avoided player code entirely.
- Added `MineViewModel` so the Mine tab owns login-state refresh, logout, and account profile loading.
- Extended the shared home snapshot with `avatarUrl` so Swift can show the logged-in account avatar in Mine.
- Updated Mine to show the logged-in username/avatar when available.
- Wired "我的订阅" in Mine to the existing real `FollowingView`.
- Replaced remaining inert Mine menu rows with explicit "not migrated yet" alerts.

## Why

The player is being deferred for a later rewrite. The Mine tab is a good non-player vertical slice because it already has login/session state and can connect to existing migrated following data.

## Mistakes Or Failed Attempts

- None.

## Verification

- Pending: local shared tests and CI build will be run after the code changes.

## Known Limits

- Settings, daily check-in, watch later, favorites, playlists, and downloads still need real feature ports.
- Profile details are loaded from the home page snapshot, not a dedicated account page yet.
