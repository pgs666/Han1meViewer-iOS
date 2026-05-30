# 技术架构

## 分层概览

```
┌─────────────────────────────────────────────┐
│                 iosApp (SwiftUI)             │
│  Views · ViewModels · Snapshots (DTO)       │
│  KSPlayer · Nuke · SwiftUI Layouts          │
├─────────────────────────────────────────────┤
│            shared (KMP Kotlin)              │
│  Models · Repositories · Features · Parser  │
│  Session · Database (SQLDelight)            │
├─────────────────────────────────────────────┤
│              Platform Layer                 │
│  iOS: Ktor/Darwin · SQLDelight/Native       │
│  JVM: Ktor/CIO · SQLDelight/JDBC (测试)     │
└─────────────────────────────────────────────┘
```

## 技术栈

| 层级 | 技术栈 | 说明 |
|------|--------|------|
| 共享业务层 | Kotlin Multiplatform | 模型、网络、解析、数据库、业务逻辑 |
| 网络 | Ktor 3.x + Darwin Engine | HTTP 客户端，自动 Cookie 管理，419 自动 refresh + retry |
| HTML 解析 | Ksoup | 多平台 Jsoup 替代方案 |
| 本地存储 | SQLDelight | 类型安全的 SQLite，iOS 使用 Native 驱动 |
| 视频播放 | KSPlayer | 自定义控件层，支持手势、长按倍速、清晰度切换、续播、本地文件播放 |
| 视频下载 | URLSession（前台） | 限并发、断点续传、链接过期自动重取（说明见下方） |
| 表现层 | SwiftUI | 原生 iOS UI，MVVM 架构（iOS 16/17/18+ 分别走最佳 API） |
| 图片加载 | Nuke (NukeUI) | 异步加载、缓存、自适应图像尺寸 |
| 诊断 | 自研 AppLogger | 脱敏操作日志，写入 Documents/Logs，Files App 可见 |
| 构建 | XcodeGen + Gradle | `project.yml` 生成 Xcode 工程，Gradle 构建 KMP 框架 |

> URLSession 选择前台模式（`URLSessionConfiguration.default`）：iOS 16 + 当前自签分发上下文下，`nsurlsessiond` 不会向我们的进程下发跨沙盒访问扩展，使得 background 模式下载完成时的临时文件无法移动到 App 沙盒。为可靠性优先选择前台模式。

## 项目目录结构

```
Han1meViewer-iOS/
├── shared/                          # KMP 共享模块
│   └── src/commonMain/kotlin/com/yenaly/han1meviewer/shared/
│       ├── model/                   # 数据模型（@Serializable）
│       ├── repository/              # 网络仓库（Ktor 实现，419 自动 refresh）
│       ├── parser/                  # HTML 解析器（Ksoup，过滤 add/remove 等噪声 anchor）
│       ├── network/                 # HTTP 客户端配置 + cookie 处理
│       ├── session/                 # Cookie 会话管理（含 Darwin Set-Cookie 拆分）
│       ├── db/                      # SQLDelight 数据库 + migrations（含 download 表）
│       ├── app/                     # 依赖注入容器
│       ├── home/ search/ video/     # 功能模块（Feature + Snapshot）
│       ├── download/                # 下载元数据持久化（DownloadStore）
│       ├── following/ userlist/ playlist/ history/ auth/
│       └── ...
├── iosApp/                          # SwiftUI iOS 应用
│   ├── Han1meViewerApp.swift        # 入口、Tab 栏（modern + legacy 双轨）
│   ├── KSPlayerView.swift           # KSPlayer 自定义控件层（手势、HUD、清晰度等）
│   ├── VideoDetailView.swift        # 视频详情主体（sticky-top + 跟手收缩 + 简介/评论）
│   ├── LocalVideoPlayerView.swift   # 本地下载文件播放（复用 KSPlayerView）
│   ├── DownloadManager.swift        # 前台 URLSession 下载引擎（限并发/断点续传/重取）
│   ├── DownloadsView.swift          # 下载列表（进度/暂停继续/删除/点击播放）
│   ├── HomeView.swift               # 首页（栏目排序应用层）
│   ├── HomeSectionOrderView.swift   # 首页栏目排序设置子页
│   ├── ArtistVideosView.swift       # 通用宫格搜索结果（标签/作者/首页栏目共用）
│   ├── AppleStyleHUD.swift          # Apple Music 风格操作反馈 HUD
│   ├── AppLogger.swift              # 脱敏操作诊断日志
│   ├── CrashReporter.swift          # 未捕获异常摘要
│   ├── *View.swift                  # 其他视图
│   ├── *ViewModel.swift             # 视图模型
│   ├── PopToRootOnSignal.swift      # 点击 tab 弹回 root
│   ├── InteractivePopEnabler.swift  # 修复 .toolbar(.hidden, .navigationBar) 后的 swipe-back
│   ├── SystemVolumeController.swift # ref-counted MPVolumeView，仅 player 期间挂载
│   ├── TabBarHiddenModifier.swift   # 二级页 hide tab bar
│   ├── SearchOptions/               # 搜索筛选 JSON 数据
│   └── ...
├── project.yml                      # XcodeGen 工程配置
├── build.gradle.kts                 # Gradle 构建脚本
└── gradle/libs.versions.toml        # 依赖版本目录
```
