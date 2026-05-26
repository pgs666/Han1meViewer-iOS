# Round 2 剩余 P1 + P2 修复

**日期**: 2026-05-26 14:30 +0800
**分支**: fix/review-bugs-performance-quality
**commit**: c0f07db

## User Input

Original:
```
review-ios-vs-android-round2.md 看看这个md，然后一条一条修复好有价值的
```

English translation:
```
Read review-ios-vs-android-round2.md and fix all valuable items one by one
```

## 改动总结

### P1-N2: UserVideoListType 从 enum 改为 value class
- **文件**: `HanimeModels.kt`
- **改动**: `enum class UserVideoListType` → `@JvmInline value class UserVideoListType(val path: String)`，保留 `WatchLater`/`Favorites` 伴生常量
- **原因**: Android `playlist_id` 接受任意 String，iOS 原 enum 限制只能用 saves/likes

### P1-P2: isPlaying 选择器范围过大
- **文件**: `KsoupHtmlParser.kt`
- **改动**: `panel?.text()?.contains("播放")` → `panel?.select("div > div > div > div")?.firstOrNull()?.text()?.contains("播放")`
- **原因**: 对齐 Android `Parser.kt:401-404` 的 4 层深选择器

### P1-P3: 评论点赞 fallback 选择器漂移
- **文件**: `KsoupHtmlParser.kt`
- **改动**: `postElement?.select("span[style]")` → `postElement?.selectFirst("#comment-like-form-wrapper")?.select("span[style]")`
- **原因**: 对齐 Android `Parser.kt:803-805`，限定在 like-form-wrapper 内

### P1-S6: player error "切换清晰度"按钮名不副实
- **文件**: `VideoDetailView.swift`
- **改动**: 按钮现在循环切换到下一个 playback source
- **原因**: 原实现只清 error 不切源，AVPlayer 仍是 failed item

### P1-S7: refreshable 让旧内容消失
- **文件**: `HomeViewModel.swift`, `PaginatedViewModel.swift`, `CommentViewModel.swift`, `HomeView.swift`, `FollowingView.swift`, `CommentView.swift`, `OnlineWatchHistoryView.swift`
- **改动**: 新增 `refresh()` 方法，不设 `state = .loading`，保留旧内容
- **原因**: `.loading` 态直接渲染 ProgressView，列表消失

### P1-S8: 评论点赞 actionID 竞态
- **文件**: `CommentViewModel.swift`
- **改动**: `actionID = "like-\(comment.id)-\(isPositive)"` → `"like-\(comment.id)"`
- **原因**: like/dislike 的 actionID 不同导致可并发进入

### P1-S10: HomeViewModel 失败后无被动重试
- **文件**: `HomeViewModel.swift`
- **改动**: `loadIfNeeded()` 现在 `.failed` 态也会触发 `load()`
- **原因**: 对齐 Android Fragment 复用时的自动重载行为

### P2-N1: 评论错误文案错位
- **文件**: `KtorCommentRepository.kt`
- **改动**: getComments→"Failed to load comments." / getCommentReplies→"Failed to load replies." / postComment→"Failed to post comment."

### P2-N2: likeComment/postReply 缺 requireSuccessfulMutation
- **文件**: `KtorCommentRepository.kt`
- **改动**: 两个方法末尾添加 `requireSuccessfulMutation`

### P2-N3: HEAD 不在重试范围
- **文件**: `Han1meHttpClient.kt`
- **改动**: `request.method == HttpMethod.Get` → `request.method in setOf(HttpMethod.Get, HttpMethod.Head)`

### P2-P1: 正则锚点过于严格
- **文件**: `KsoupHtmlParser.kt`
- **改动**: 移除 `VIEW_AND_UPLOAD_TIME_REGEX` 的 `^...$` 锚点

### P2-P2: 模型默认值不一致
- **文件**: `KsoupHtmlParser.kt`, `HanimeModels.kt`
- **改动**: `UserPlaylist.total` 默认 `?: -1`，`VideoComment.id` 默认 `"-1"`

### P2-D1: record 默认参数清零进度
- **文件**: `WatchHistoryStore.kt`
- **改动**: `record()` 在 `playbackPositionMillis == 0` 时保留已有进度

## 验证

- 本地 JVM 测试: 通过
- CI: `26453309090` 通过

## 仍未修复

| 编号 | 项目 | 原因 |
|------|------|------|
| P1-N1 | 删除响应校验 | 需要解析返回 JSON |
| P1-N3 | 404 不分流为"未登录" | 需要 isAlreadyLogin 状态 |
| P1-N4 | 缺多个 mutation 端点 | 需要 UI 配合 |
| P1-P1 | 新番预告区块 | 需要 HTML fixture |
| P1-C1 | CF presenter 冲突 | 需要 iOS 架构改动 |
| P1-C2 | CF 挑战过早关闭 | 需要更复杂检测 |
| P1-S2 | 搜索历史不恢复 filters | 需要扩展数据模型 |
| P1-D3 | 无 Flow 订阅 | 需要 SQLDelight asFlow |
| P1-D4 | 偏好设置不足 | 需要大量 UI 工作 |
| P2-C1/C2 | cookie path/lang | 低优先级 |
| H3/H5 | 备用域名/CF 自动重发 | 架构层面 |
