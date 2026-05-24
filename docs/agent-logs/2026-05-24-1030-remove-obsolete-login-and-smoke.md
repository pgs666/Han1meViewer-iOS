# Agent Log: Remove Obsolete Login And Smoke Code

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
根据要求对整个仓库的代码进行修改，去除掉无意义的冗余
```

English translation:

```text
Modify the whole repository according to the requirements and remove meaningless redundancy.
```

## Changes

- Removed unused Swift `LoginViewModel`.
- Removed the old Ktor form-login stack:
  - `AuthFeature`
  - `AuthRepository`
  - `KtorAuthRepository`
  - `LoginResult`
  - login CSRF parser API and its test
- Removed early bridge smoke scaffolding:
  - `SharedSmokeTest`
  - `SmokeFetchResult`
  - `SmokeTestTest`
- Removed the now-unused `authFeature()` factory from `SharedAppEnvironment`.

## Why

The app now uses WebView login and real Home/Search/Video KMP slices. The old form-login chain and smoke test were temporary migration scaffolding, so preserving them only adds noise.

## Mistakes Or Failed Attempts

- The first patch attempt used stale context for the parser test name and did not apply. I split the deletion into smaller patches and reapplied it.

## Verification

- Pending local Gradle test and GitHub Actions build.

## Known Limits

- This intentionally does not preserve the old prototype form-login path.
