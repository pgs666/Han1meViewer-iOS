# Fix User List Mutations and User ID Cache

## User Request

中文原文：

> 一、仍需修复的 Bug
>
> 🟡 中等
>
> 1. removeUserVideoListItem 收藏删除逻辑可能错误
> - 文件: shared/.../repository/KtorUserVideoListRepository.kt:81-97
> - 问题: 删除收藏时 like-status 固定发送 "1"（表示喜欢），这是 toggle 操作而非确定性删除。如果服务端已取消喜欢，这会重新喜欢它。
> - 修复: 需要先读取当前 like-status，发送相反值。
>
> 2. VideoDetailViewModel 无任务取消机制
> - 文件: iosApp/VideoDetailViewModel.swift:29-38
> - 问题: 快速切换视频时，前一个加载任务不会取消，两个并发任务可能竞争写入 state，导致显示错误视频。
> - 修复: 在 load() 中保存 Task 引用并在新加载时取消前一个。
>
> 3. UserVideoListFeature.load() 每次都请求首页来获取 userId
> - 文件: shared/.../userlist/UserVideoListFeature.kt:17
> - 问题: 每次打开"稍后观看"或"收藏"列表都会请求并解析整个首页 HTML，只为获取 userId。
> - 修复: 在 SharedAppEnvironment 或 SessionStore 中缓存 userId。

English translation:

> Remaining bugs to fix:
>
> 1. `removeUserVideoListItem` may have incorrect favorite deletion logic. It always sends `like-status = "1"`, which is a toggle-like operation rather than deterministic deletion. If the server already removed the favorite, this could add it again. Fix by reading the current like status first and sending the opposite value.
>
> 2. `VideoDetailViewModel` has no task cancellation. When switching videos quickly, the previous load task may still write state and show the wrong video. Fix by storing the `Task` in `load()` and canceling the previous one before starting a new one.
>
> 3. `UserVideoListFeature.load()` requests and parses the home page every time just to get `userId`. Cache `userId` in `SharedAppEnvironment` or `SessionStore`.

## Changes

- Made favorite-list removal deterministic by loading the current video page before mutation.
- If the video is no longer favorited, removal returns without submitting another toggle request.
- Reused the parsed video CSRF token and current user ID for the favorite mutation when available.
- Moved user ID caching to `SharedAppEnvironment` and passed a cached provider into `UserVideoListFeature`.
- Clear the cached user ID after logout succeeds, so a later account session does not reuse stale identity.
- Confirmed `VideoDetailViewModel` already cancels previous load tasks; added `deinit` cancellation for lifecycle cleanup.

## Verification

- Passed `./gradlew :shared:jvmTest`.
