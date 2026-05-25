# Agent Log: Comment Like Counts

Time: 2026-05-26 03:18:00 +08:00

Repository: `/home/pgs/Project/Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## User Input

Original:

```text
评论区赞的数量貌似不能正确加载，连带着按赞数量排序功能也失效了，修复它
```

English translation:

```text
The like counts in the comments section seem not to load correctly, which also breaks sorting by like count. Fix it.
```

## What Changed

- Parse comment like counts from `comment-likes-sum` and `comment-likes-count` hidden inputs before falling back to the old hidden span position.
- Reuse the parsed hidden input values when building `VideoCommentPost`.
- Added parser assertions for parent comments and replies, plus a regression test where the style span count is missing or invalid.

## Why

The parser depended on the second `span[style]` value inside the comment like form. That is fragile when the site changes markup or adds hidden spans, causing `thumbUp` to become null and making like-count sorting behave as if comments have zero likes.

## Verification

Planned verification for this change:

- Run `git diff --check` locally.
- Run `:shared:jvmTest` with JDK 21.
- Push the change and wait for the relevant GitHub Actions workflow.
