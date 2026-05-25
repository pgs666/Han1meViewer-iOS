# 2026-05-25 21:10 Review fourth round fixes

## Request

Re-read `/home/pgs/Project/review/*.md` and fix bugs and code quality issues from the fourth-round review.

## Changes

- Hardened login/session handling: cancellation is rethrown, transient verification errors no longer clear cookies, logout clears cached current user id, and concurrent user id resolution is serialized.
- Added cookie security coverage: `Expires` parsing, `Secure` persistence, insecure-transport filtering, expired cookie cleanup, and a SQLDelight migration for the new `secure` column.
- Improved network/parser robustness: Cloudflare detection now handles additional mitigation signals, production HTTP logging is disabled, comment JSON fields are accessed safely, upload metadata regex is non-greedy, JS video source regex supports common quote styles, and favorite status checks the expected sentinel.
- Fixed iOS runtime risks: player seek callbacks verify the active player before resuming, search pagination captures state safely, crash reporting also records POSIX signals, tag identities tolerate duplicate labels, and following artist identity no longer uses only the name.
- Tightened comment reporting by rejecting missing `userId` instead of posting to `/user//report`.

## Validation

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest && git diff --check` passed locally.
- `./gradlew --stop` was blocked by the read-only Gradle wrapper lock file in this sandbox; `ps -ef | grep -E 'GradleDaemon|KotlinCompileDaemon|gradle' | grep -v grep || true` returned no leftover Gradle/Kotlin daemon process.
- Pending: push and watch GitHub Actions iOS build.
