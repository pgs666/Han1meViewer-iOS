# Agent Log: Login Auto Dismiss

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
登录成功后登录界面不会自动退出并弹出登录成功提示，我的界面的账户登录按钮也不会提示当前登录状态
```

English translation:

```text
After login succeeds, the login screen does not automatically exit and show a login-success prompt, and the account login button on the Mine screen does not indicate the current login state.
```

## Changes

- Added an `onLoginSuccess` callback to `LoginView`.
- Automatically dismisses the login screen after the WebView cookie import confirms a login session.
- Added a guard so repeated WebView navigation/cookie callbacks do not fire duplicate success events.

## Why

The WebView login flow should behave like a native login screen: once authenticated state is captured, the user should return to the previous screen instead of being left on the login page.

## Verification

- Pending GitHub Actions iOS build.

## Known Limits

- The success alert is handled by `MineView`, not inside the dismissed login view.
