# Player Source Switching Plan

## User Input

Original:

```text
继续下一步
```

English translation:

```text
Continue to the next step.
```

## What I Plan To Change

- Expose all parsed playback sources from `VideoFeature`, not only the default URL.
- Map those sources into Swift rows.
- Update `VideoDetailView` to open `PlayerView` with the full source list.
- Update `PlayerView` to provide a quality/source picker and switch the `AVPlayer` item while preserving playback position when possible.

## Why

The parser already extracts multiple `<source>` entries. The current iOS UI discards them and only plays the default source, so users cannot choose quality. This is a natural next step for the playback MVP.

## Verification Planned

- Run `./gradlew :shared:jvmTest`.
- Push and wait for GitHub Actions `iOS App Build`.

## Known Limits

- Switching source preserves the current timestamp, but it cannot guarantee continuity if two source URLs have different timelines.
