# Agent Log: Web Login Logout Feature

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

- Added `WebLoginFeature.logout()` to clear the persisted KMP session cookies.
- Added a unit test confirming logout clears the current session state.

## Why

The logout prompt should perform a real logout from the shared session store, not only change the SwiftUI display state.

## Verification

- Pending `./gradlew :shared:jvmTest`.

## Known Limits

- This KMP method clears shared cookies. Platform browser cookies are cleared from the iOS layer.
