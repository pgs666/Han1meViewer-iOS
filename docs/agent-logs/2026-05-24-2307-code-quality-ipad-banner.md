# Improve Code Quality And iPad Home Banner

## User Input

Original:

```text
开始改善代码质量，顺便修复当前iPad下首页的banner
```

English translation:

```text
Start improving code quality, and also fix the current home page banner on iPad.
```

## Changes

- Reworked the home page banner sizing so iPad uses a stable compact banner frame instead of allowing the image to grow too tall.
- Replaced deprecated `@Environment(\.presentationMode)` usage with `@Environment(\.dismiss)` in login and Cloudflare challenge views.
- Replaced remaining SwiftUI `.foregroundColor(...)` usages with `.foregroundStyle(...)`.
- Added a shared Ktor `HttpClient` in `SharedAppEnvironment` and injected it into the Ktor repositories created by the app environment.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only existing line-ending warnings for edited files.
- `rg` found no remaining `.foregroundColor(...)` or `presentationMode` usage in `iosApp`.
- Swift compilation still needs CI or Xcode verification.
