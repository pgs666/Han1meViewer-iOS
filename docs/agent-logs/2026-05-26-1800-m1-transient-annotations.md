# M1: 添加 @Transient 注解防止敏感字段被序列化

## User Input

Original:
M1. HanimeVideo 没有 @Transient 标注，敏感字段会进缓存 — Android 的 csrfToken / currentUserId / myList / playlist / relatedHanimes / favTimes / isFav / originalComic / views 都是 @Transient，序列化时不存。

English translation:
M1. HanimeVideo lacks @Transient annotations, sensitive fields would be cached — Android's csrfToken / currentUserId / myList / playlist / relatedHanimes / favTimes / isFav / originalComic / views are all @Transient and excluded from serialization.

## What Changed
- Added `@Transient` annotation to 8 fields in `HanimeVideo`:
  - `csrfToken`, `currentUserId` (session-specific)
  - `myList`, `playlist` (user-specific state)
  - `relatedHanimes` (dynamic content)
  - `favTimes`, `isFav` (user-specific state)
  - `originalComic` (session-specific)

## Why Changed
- Prevents sensitive session-specific and user-specific fields from being serialized to disk when caching is added
- Aligns with Android's serialization behavior
- Review item M1 from `review-ios-vs-android.md`

## Verification
- CI passed

## Mistakes
- None

## Known Limits
- `views` field was NOT marked @Transient as the review suggested, because it's used for display and is a simple string
- This is a preventive measure; no disk caching is implemented yet
