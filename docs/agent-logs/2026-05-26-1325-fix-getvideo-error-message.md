# Fix getVideo Error Message

Date: 2026-05-26 13:25:00 +08:00

## What Changed

Changed `KtorVideoRepository.getVideo` error message from "Failed to update favorite state." to "Failed to load video."

## Why

The error message was copy-pasted from `setFavorite` and is misleading when the actual failure is loading a video detail page, not updating the favorite state.

## Verification

- `git diff --check` passed locally.

## User Input

Original:

```text
查看review文件夹，听从里面的建议，并修复你觉得有价值的问题，一次修复一个并推送等待ci，然后再选择下一个问题开始修复
```

English translation:

```text
Check the review folder, follow the suggestions, and fix issues you think are valuable. Fix one at a time, push and wait for CI, then choose the next issue to fix.
```
