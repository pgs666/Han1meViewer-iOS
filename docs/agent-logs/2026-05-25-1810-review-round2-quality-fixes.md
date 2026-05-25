# 2026-05-25 18:10 Review round 2 quality fixes

## Request

Read `/home/pgs/Project/review/REVIEW.md` and fix reported bugs and code quality issues in `Han1meViewer-iOS`.

## Fixed in this pass

- Replaced the empty playlist `"更多"` action with a navigable full related-video grid.
- Changed `VideoDetailViewModel.runAction` tasks to capture `self` weakly.
- Removed the `WKHTTPCookieStore` observer in `CloudflareWebView.dismantleUIView`.
- Moved cache size calculation and cache clearing off the main thread.
- Loaded search option JSON off the main thread and deferred home-section launch handling until the catalog is ready.
- Added a compatible navigation wrapper that uses `NavigationStack` on iOS 16+ and keeps `NavigationView` only for iOS 15 fallback.
- Added an `onValueChange` compatibility wrapper to avoid deprecated call sites while keeping iOS 15 support.
- Added entitlements wiring, build-setting-based bundle versions, ATS media/local-network settings, and simulator x86_64 support in the KMP target.
- Tightened the video upload metadata regex and removed the unused `genre_av.json` resource.
- Updated README status so comments are no longer listed as pending.

## Validation

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:compileKotlinMetadata && git diff --check`
- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew --stop && sleep 2 && ps -ef | grep -E 'GradleDaemon|KotlinCompileDaemon|gradle' | grep -v grep || true`

## Remaining from review

- Comment sorting still cannot be fully language-independent until the upstream/shared model exposes server timestamps.
- Deep linking and crash reporting are product features rather than small quality fixes.
- Structured advanced-search history requires a database migration and should be handled separately.
