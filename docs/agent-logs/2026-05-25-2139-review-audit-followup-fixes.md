# 2026-05-25 21:39 Review audit follow-up fixes

## Request

Re-read `/home/pgs/Project/review/*.md` and continue fixing bugs and code quality issues.

## Findings

- `/home/pgs/Project/review/ios-code-audit.md` was present in addition to `REVIEW.md` and listed first-round critical/high issues not fully covered by the previous pass.
- `DatabaseFactory.ios.kt` uses SQLDelight 2.1's `NativeSqliteDriver(schema, name)` constructor, whose current source wires `create` and `upgrade` callbacks from the schema. The reviewed `DatabaseConfiguration.Callback` sample does not match SQLDelight 2.1 APIs, so this pass did not add an incompatible callback.

## Changes

- Fixed comment like parsing to read `foreign_id` and `is_positive` from `input[name=...]`, with regression assertions.
- Routed all parser entry points through `Ksoup.parse(html, "https://hanime1.me")` so `absUrl()` resolves relative URLs.
- Broadened upload metadata parsing for traditional Chinese, simplified Chinese, and English `Views` labels.
- Added HTTP response validation for 401/403 auth expiry, 404, 429, and 5xx responses.
- Ensured `MineViewModel` always unlocks `isCheckingLogin` for the active request, including cancellation paths.
- Moved local watch-history load/delete work off the main actor with detached tasks.
- Switched Gradle Wrapper back to official `services.gradle.org` distribution URL.

## Validation

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest && git diff --check` passed locally.
- `./gradlew --stop` stopped the Gradle daemon after switching to the official wrapper; `ps -ef | grep -E 'GradleDaemon|KotlinCompileDaemon|gradle' | grep -v grep || true` returned no leftover Gradle/Kotlin daemon process.
- Pending: push and watch GitHub Actions iOS build.
