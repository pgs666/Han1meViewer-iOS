# Agent Log: Cancellable Root Loads

## Summary

- Replaced root `onAppear` loads in Following and Mine with `.task`.
- Added explicit cancellation hooks so in-flight root loads stop when those views disappear.
- Restored Following state from loading/loading-more when cancellation happens before completion.

## Validation

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest --parallel --max-workers=$(nproc)` passed locally.
- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew --stop` stopped the Gradle daemon.
- `ps -ef | grep -E 'GradleDaemon|KotlinCompileDaemon|[g]radle' | grep -v grep || true` returned no leftover Gradle/Kotlin daemon process.
