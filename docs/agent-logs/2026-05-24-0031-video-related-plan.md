# Video Related Items Plan

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

- Expose parsed related videos from `VideoFeature`.
- Add Swift-side mapping for related video rows.
- Add a `相关影片` section to `VideoDetailView`.
- Let related rows navigate to another `VideoDetailView`.

## Why

`KsoupHtmlParser` already parses `relatedHanimes`, but the current KMP snapshot drops them. Showing related videos makes the video detail page closer to the Android feature and improves the viewing/browsing flow without adding a new endpoint.

## Verification Planned

- Run `./gradlew :shared:jvmTest`.
- Push and wait for GitHub Actions `iOS App Build`.

## Known Limits

- This only displays related videos. It does not yet add artist pages, playlists, or follow/unfollow actions from video detail.
