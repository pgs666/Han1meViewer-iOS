# Remove Development-Only Items From v0.1.3 Draft

## User Input

Original:

```text
部分问题是仅在开发中途出现的，这些问题没必要写进去，比如 修复详情页左右分页手势与系统左侧返回手势冲突的问题；从屏幕边缘返回时由系统手势优先处理
```

English translation:

```text
Some problems only appeared midway through development and do not need to be included, for example: fixed a conflict between the detail page's horizontal paging gesture and the system's left-edge back gesture; the system gesture now takes priority when navigating back from the screen edge.
```

## What Changed

- Removed release-note entries for problems introduced and resolved within this branch's development cycle:
  - pager versus interactive-pop gesture arbitration;
  - reopening the currently playing item from the newly introduced series sheet;
  - the transient narrow-iPhone fit issue in the new related-video grid.
- Shortened the final two-column related-video improvement so it describes only the resulting user-facing layout.

## Why

Release notes should compare the released baseline with the final release behavior. They should not expose temporary regressions that users of the previous release never encountered.

## Mistakes Or Failed Attempts

- The initial draft treated several intermediate corrective commits as standalone user-facing bug fixes. This overrepresented development history instead of the net release change.

## Verification

- Re-read the remaining entries against the `origin/main...feature/video-pager-rebuild` net diff.
- Confirmed that the explicitly identified gesture item and the other branch-internal follow-up fixes no longer appear in the release draft.
- Documentation-only update; no application code changed, so no JVM test or build CI was run.

## Known Limits

- The draft may be tightened further once the final release scope and version number are confirmed.
