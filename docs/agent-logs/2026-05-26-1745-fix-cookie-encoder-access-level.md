# Fix: Cookie 编码函数访问级别

## User Input

Original:
H6. WebView 抽 cookie 丢元数据（expires / secure / httpOnly）

English translation:
H6. WebView cookie extraction loses metadata (expires / secure / httpOnly)

## What Changed
- Changed `encodeCookiesForImport` from `private static` to `fileprivate static` in `LoginView.swift`

## Why Changed
- The function was declared as `private` on `LoginView` struct
- It was called from `Coordinator` class which is nested inside `WebLoginView` (a separate struct)
- In Swift, `private` restricts access to the same declaration scope
- `Coordinator` is in a different scope (nested inside `WebLoginView`, not directly inside `LoginView`)
- Changing to `fileprivate` allows access within the same file

## Mistakes
- Initial implementation used `private` without considering the nested type hierarchy
- The CI error message was clear: "'encodeCookiesForImport' is inaccessible due to 'private' protection level"

## Verification
- CI passed on the fix commit (26436212938)

## Known Limits
- None
