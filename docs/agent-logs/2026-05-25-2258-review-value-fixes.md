# Agent Log: Review Value Fixes

## Summary

- Replaced shared current-user cache writes with a multiplatform atomic reference to avoid unsynchronized reads/writes.
- Replaced the user-video-list CSRF cache with a multiplatform atomic reference.
- Added mutation guard helpers so missing CSRF/user IDs fail before sending empty values.
- Changed online watch history delete failures from `IllegalStateException` to `DomainException`.
- Removed private orientation KVC calls from the iOS orientation controller.

## Validation

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest --parallel --max-workers=$(nproc) && git diff --check` passed locally.
- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew --stop` stopped the Gradle daemon.
- `ps -ef | grep -E 'GradleDaemon|KotlinCompileDaemon|[g]radle' | grep -v grep || true` returned no leftover Gradle/Kotlin daemon process.
