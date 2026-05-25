# 2026-05-25 22:30 Android parity home parser review

## Request

Review the current iOS/KMP port against the Android implementation and fix issues found.

## Findings

- Search option JSON resources match Android for shared domains; Android has an extra `genre_av.json` only used when `Preferences.baseUrl == https://javchu.com/`, while the iOS port currently hardcodes `https://hanime1.me` and has no AV-domain selector.
- The shared home parser mapped `#home-rows-wrapper` rows by contiguous index and emitted `unknown4` / `unknown9` sections. Android explicitly skips row indexes 4 and 9, so iOS could show unlabeled/incorrect home categories if those rows contain cards.
- Android also falls back to finding the banner video code in banner-wrapper comments when no script contains `watch?v=`; the shared parser only checked scripts.

## Changes

- Replaced contiguous home section keys with explicit Android-compatible row index mappings.
- Added banner video-code fallback against the banner wrapper HTML, covering commented `watch?v=` links.
- Added a shared parser regression test that verifies skipped row indexes and banner comment fallback.

## Validation

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest && git diff --check` passed locally.
- `./gradlew --stop` reported no Gradle daemons running afterward.
- `ps -ef | grep -E 'GradleDaemon|KotlinCompileDaemon|[g]radle' | grep -v grep || true` returned no leftover Gradle/Kotlin daemon process.
