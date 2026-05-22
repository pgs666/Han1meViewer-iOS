# Agent Log: Avoid Web Login Double Load

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
登录界面在安卓上是一个网页，ios上这个没法正常登录的
```

English translation:

```text
The login screen on Android is a web page; on iOS this cannot log in normally.
```

## Changes

- Initialized the WebView coordinator's `reloadToken` when creating the `WKWebView`.

## Why

Without this, SwiftUI could call `updateUIView` immediately after `makeUIView` and trigger a second login-page load because the coordinator had not recorded the current token yet.

## Verification

- Pending GitHub Actions iOS build.
