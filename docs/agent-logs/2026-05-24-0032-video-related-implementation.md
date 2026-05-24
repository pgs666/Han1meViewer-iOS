# Video Related Items Implementation

## User Input

Original:

```text
继续下一步
```

English translation:

```text
Continue to the next step.
```

## What Changed

- Added `VideoRelatedSnapshot` to the shared KMP video feature.
- Included parsed `relatedHanimes` in `VideoDetailSnapshot`.
- Added Swift-side `VideoDetailScreenSnapshot` and `VideoRelatedRow` mapping.
- Added a `相关影片` section to `VideoDetailView`.
- Related video rows use cached remote images and navigate to another `VideoDetailView`.

## Why

The parser already extracted related videos, but the app UI discarded them. Showing them in the detail page improves browsing continuity and moves the video detail screen closer to the Android feature set.

## Mistakes Or Failed Attempts

- I initially referenced a non-existent `viewModel.videoFeatureForNavigation` property from `VideoDetailView`. I corrected it by storing the injected `VideoFeature` in `VideoDetailView` and reusing it for related-item navigation.

## Verification Planned

- Run `./gradlew :shared:jvmTest`.
- Push and wait for GitHub Actions `iOS App Build`.

## Known Limits

- The detail page still uses a basic list layout.
- Related videos rely on the current parser selector and may be empty when the site changes the detail page structure.
