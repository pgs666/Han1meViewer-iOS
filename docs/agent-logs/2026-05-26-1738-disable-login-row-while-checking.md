# 检测登录状态时禁用账户入口

## User Input

Original:
我希望在检测登录状态的时候，按钮是不可点击的，现在在检测过程中点击会问要不要清除登录状态

English translation:
I want the button to be unclickable while checking login status. Currently, tapping it during checking asks whether to clear the login state.

## What Changed
- `MineView.swift` now renders the account row as a plain non-interactive row while `isCheckingLogin` is true.
- The logout confirmation button is only available after login checking finishes and the user is confirmed logged in.
- The web login navigation link is only available after login checking finishes and the user is confirmed logged out.

## Why Changed
- During startup/session refresh, `isLoggedIn` can still reflect the previous local state while `isCheckingLogin` is true.
- The old branching checked `isLoggedIn` first, so tapping during refresh could enter the logout flow before the session check completed.

## Verification
- Pending CI after push.
- No local Swift build is available in this Linux environment.

## Mistakes
- None in this fix.

## Known Limits
- This only changes the account row interaction during login-state checking; other Mine page rows remain interactive.

## Follow-up: Login Check Timeout
- The first inspection found no whole-flow timeout in `MineViewModel.refreshLoginState()`.
- Shared Ktor HTTP requests already have `requestTimeoutMillis = 30_000`, `connectTimeoutMillis = 15_000`, and `socketTimeoutMillis = 30_000`.
- Added a 20 second UI-level timeout for the Mine page login-state check so the account row cannot remain stuck in the checking state while multiple async calls are chained.
