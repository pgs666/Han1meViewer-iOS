# Agent Log: Mine Logout Confirmation

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
登录状态下点击账户按钮会弹出是否退出登录按钮
```

English translation:

```text
When logged in, tapping the account button should show a prompt asking whether to log out.
```

## Changes

- Changed the Mine account row behavior:
  - Logged out: row navigates to WebView login.
  - Logged in: row opens a logout confirmation alert.
- Added logout handling that clears both:
  - KMP persisted session cookies through `WebLoginFeature.logout()`.
  - iOS `WKWebsiteDataStore` cookies for `hanime1.me`.
- Updated the logged-in subtitle to say that tapping can log out.

## Why

The account entry should reflect the current state. When the user is already logged in, tapping it should offer account-session management instead of reopening the login page.

## Verification

- Pending local test and GitHub Actions build.

## Known Limits

- Logout does not call a remote website logout endpoint; it clears local app and WebView session state.
