# 2026-05-25 19:02 Review third round fixes

## Request

Re-read `/home/pgs/Project/review/REVIEW.md` and fix remaining bugs and code quality issues.

## Findings

- `VideoDetailViewModel.runAction` already uses `[weak self]`.
- `Info.plist` already reads `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` build settings.
- `project.yml` no longer excludes x86_64 simulators and shared KMP declares `iosX64()`.

## Changes

- Replaced the remaining empty tag button action with `SearchNavigationCenter.open(keyword:)`.
- Added `SearchNavigationCenter` and app-level notification handling so video detail tag taps switch to the Search tab and run the query.
- Tightened video metadata parsing to match `觀看次數：...次 YYYY-MM-DD` explicitly instead of using a generic prefix capture.
- Kept parsed view counts as raw numeric text and added a parser regression assertion to avoid localized unit duplication in the UI.

## Validation

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest && git diff --check` passed locally.
- `./gradlew --stop` was blocked by the wrapper lock file being read-only in this sandbox, but `ps -ef | grep -E 'GradleDaemon|KotlinCompileDaemon|gradle' | grep -v grep || true` returned no leftover Gradle/Kotlin daemon process.
- Pending: push and watch iOS CI.
