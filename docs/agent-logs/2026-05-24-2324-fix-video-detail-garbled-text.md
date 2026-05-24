# Fix Video Detail Garbled Text

## User Input

Original:

```text
还有这里的乱码修一下
```

English translation:

```text
Also fix the garbled text here.
```

## Changes

- Fixed garbled static UI text in `VideoDetailView.swift`.
- Replaced the iPad related-video sidebar title with `相关影片`.
- Replaced other visible video detail strings, including navigation title, failed state, tabs, quality picker, action buttons, subscription confirmation, tags, series videos, playing badge, and comments placeholder.
- Did not change player behavior or data parsing.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- `rg` found no remaining matching mojibake markers in `iosApp/VideoDetailView.swift`.
- Swift compilation still needs CI or Xcode verification.
