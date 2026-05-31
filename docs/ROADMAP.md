# 路线图

iOS 端已对齐 Android 上游的核心链路：浏览、搜索、视频详情、评论（含发表 / 回复）、播放（KSPlayer 自定义控件）、下载、用户列表（收藏 / 稍后 / 在线历史 / 本地历史）、账号 / 登录 / Cloudflare。本文件列出相对 Android 上游**后续计划移植**与**明确不做**的功能，作为路线图的唯一权威来源。

> 已实现功能清单见 [FEATURES.md](FEATURES.md)。

## 计划移植

按优先级排序。「shared 层现状」指 KMP 共享业务层是否已有支撑，决定了该功能主要是补 SwiftUI UI 还是需要先扩展共享层。

| 功能 | 优先级 | 说明 | shared 层现状 | Android 对应 |
|------|------|------|------|------|
| 手动 / 扫码 Cookie 导入 | 高 | WebView 登录之外的兜底：手动粘贴或扫码导入 Cookie 登录 | 已具备（`session/` 下 cookie 桥 KtorCookieBridge / CookieHeaderProvider） | `ManualInputCookiesScreen` |
| 播放清单写操作 | 中 | 新建 / 改名 / 删除清单、视频移入移出（现仅支持查看清单与清单内视频） | 部分具备（`UserPlaylistFeature`） | `MyplayListBottomSheet` + `MyPlayListViewModelV2` |
| 用户账户页 | 中 | 个人资料详情展示（现仅 Mine 卡片基本信息） | 部分具备 | `AccountScreen` + `UserAccountViewModel` |
| 月度预览 | 低（工作量大） | 月度新番日历 | 需新建 PreviewFeature + parser | `PreviewScreen` + `PreviewViewModel` |

## 明确不做

| 功能 | 原因 |
|------|------|
| 每日签到（DailyCheckIn） | 已明确排除出 iOS 迁移范围；`AGENT_WORKING_RULES.md` 规定不得移植或重新引入 |
| H 关键帧 / 共享关键帧（HKeyframe / SharedHKeyframes） | 迁移计划列为 out-of-scope |
| mpv 播放器设置 | iOS 端使用 KSPlayer，不适用 |
| Firebase / Android 更新通道 / Widget / WorkManager | Android 平台特性，iOS 不适用 |

## 细粒度设置项差距

Android 有、iOS 暂无的布局类配置，按需补：

| 配置 | 说明 |
|------|------|
| 搜索结果网格列数 | Android `SearchGridColumnsDialog` |
| 首页横向卡片数量 | Android `HorizontalCardCountDialog` |
