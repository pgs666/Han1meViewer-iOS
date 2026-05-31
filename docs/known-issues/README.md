# 已知问题

| 问题 | 现状 | 说明 |
| --- | --- | --- |
| 首页大标题滚动收缩为自绘实现 | 已缓解 | 为避免侧滑返回时「首页」标题闪现在播放器上层，首页隐藏系统导航栏并自绘标题。视觉接近系统大标题，但收缩曲线与 Dynamic Type 自适应不完全一致，待未来 UIKit 导航重构后还原（详见 [nav-bar-title-crossfade-over-player.md](nav-bar-title-crossfade-over-player.md)）。 |
| 切换域名需重启应用 | 设计如此 | 与安卓版一致——各网络仓库在启动时固定 baseURL，切换域名后需完全退出并重开应用才生效。 |
| 切换域名后需重新登录 | 设计如此 | Cookie 按域名隔离，切到新域名等于访问另一站点，需在新域名重新登录。 |
| 部分动画在 iOS 16 缺失 | 受系统限制 | 标签栏滑动等动画依赖 iOS 17+ API，iOS 16 上功能正常但无对应动画。 |
| 切到「我的」后立即进子页丢失 push 动画 | 待重构 | iOS 17+ 的 TabView 对「懒加载标签首次出现即 push」不带转场动画（iPadOS 16 不复现）。仅影响观感，功能正常，待未来 UIKit 导航重构解决（详见 [mine-first-push-animation-lost.md](mine-first-push-animation-lost.md)）。 |
| 后台下载暂停 | 设计如此 | iOS 16 + 当前签名/分发上下文下 background URLSession 的跨沙盒访问扩展不可用，下载使用前台 URLSession。App 被系统挂起足够久会暂停下载，回到 App 自动续。 |

> 如发现此处未列出的问题，欢迎到 [GitHub Issues](https://github.com/pgs666/Han1meViewer-iOS/issues) 提交。提交方式（含崩溃日志和诊断日志的获取）请参照仓库 [README](../../README.md#-问题反馈) 的「问题反馈」章节。
