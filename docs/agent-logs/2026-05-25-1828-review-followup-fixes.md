# 2026-05-25 18:28 Review follow-up fixes

## Request

Continue fixing bugs and code quality issues from `/home/pgs/Project/review/REVIEW.md`.

## Changes

- Made search history storage structured by adding a `filter_summary` SQLDelight column, updating inserts, and adding a migration for existing databases.
- Kept backward compatibility for legacy encoded search-history rows during reads.
- Reused the shared cached current-user-id provider for online watch history and playlist loading, avoiding repeated home-page requests for user id resolution.
- Added custom URL scheme deep links (`han1me://`, `hanimeviewer://`) and routing for video detail and search links.
- Removed locale-dependent comment date parsing from latest/earliest sorting; latest now preserves server order and earliest reverses it.
- Enabled automatic signing configuration by default while CI still overrides signing for unsigned builds.
- Added local uncaught-exception crash report capture and a Settings section to view/clear the latest report.

## Validation

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest && git diff --check`
- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew --stop && sleep 2 && ps -ef | grep -E 'GradleDaemon|KotlinCompileDaemon|gradle' | grep -v grep || true`
