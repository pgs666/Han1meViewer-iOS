## User Input

Original:

```text
Han1meViewer-2026-05-24-183222.ips
```

English translation:

```text
Han1meViewer-2026-05-24-183222.ips
```

## Crash Analysis

- The crash log shows `SIGABRT` from Kotlin/Native unhandled exception handling.
- The last exception is a Ktor Darwin request failure: `DarwinHttpRequestException`.
- The failing path crosses the Kotlin/Native Objective-C export boundary through `Kotlin_ObjCExport_ExceptionAsNSError`.

## What Changed

- Added `@Throws(Exception::class)` to public KMP `suspend` feature methods that are called from Swift.

## Why

- Swift ViewModels already use `try await` and `catch`, but Kotlin/Native needs exported Kotlin exceptions declared so failures can safely bridge to Swift instead of terminating the process.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI verification.
