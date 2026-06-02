# Agent Log: Hide Series Video Metadata Footer

## User Input

Original:

```text
目前版本的“系列影片”一栏和界面都有问题，标题卡片下方的作者和发布时间没法正常显示。
那就不需要实现了，直接对这个系列影片特殊处理，不显示那一行
```

English translation:

```text
In the current version, the "Series Videos" section and UI have problems; the author and publish time under the title card cannot display normally.
Then there is no need to implement parsing; just special-case this Series Videos section and do not show that line.
```

## What Changed

- Added a `showsMetadataFooter` flag to `RelatedVideoCard`.
- Passed that flag through `HorizontalVideoSection` and `RelatedVideoListView`.
- Set `showsMetadataFooter: false` for the video detail "系列影片" section only.

## Why

The series playlist data currently does not reliably include author and upload-time metadata, and the user requested a direct UI special case instead of parser work. Hiding the footer avoids placeholder or broken-looking metadata in both the inline horizontal section and the "更多" list.

## Verification

- Ran `git diff --check`; it passed.
- Checked Swift call sites for `HorizontalVideoSection`, `RelatedVideoListView`, and `RelatedVideoCard`.

## Known Limits

- This intentionally does not add series playlist author/upload-time parsing.
- This Linux environment cannot run Xcode/iOS compilation locally.
