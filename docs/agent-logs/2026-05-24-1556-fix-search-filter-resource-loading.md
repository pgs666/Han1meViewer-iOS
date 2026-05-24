## User Input

Original:

```text
接下来修复这个问题
```

English translation:

```text
Next, fix this issue.
```

## What Changed

- Fixed search filter option loading in `iosApp/SearchFilterOptions.swift`.
- The app now first looks for JSON files under the `SearchOptions` bundle subdirectory, then falls back to the app bundle root.

## Why

- The downloaded IPA showed the search option JSON files were packaged at the app bundle root, for example `Payload/Han1meViewer.app/genre.json`.
- The previous loader only searched `SearchOptions/genre.json`, so every filter section displayed the loading failure placeholder.

## Mistakes Or Failed Attempts

- No failed implementation attempt in this step.

## Verification

- Confirmed the JSON files exist in the unpacked IPA bundle root.
- Pending local tests and GitHub Actions iOS build after this log and code change.

## Known Limits

- This fixes the resource lookup path. It does not change the filter UI layout or search behavior.
