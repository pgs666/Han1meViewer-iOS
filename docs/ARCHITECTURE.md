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
│   ├── App/                         # 应用入口、域名配置和导航基础设施
│   ├── Core/                        # 跨功能的诊断、存储、系统及通用 UI
│   ├── Features/                    # 按业务功能组织的 View、ViewModel 和模型
│   │   ├── Auth/                    # 登录与 Cloudflare 验证
│   │   ├── Downloads/               # 下载 UI、调度器、模型和 URLSession delegate
│   │   ├── Home/ Search/            # 首页、搜索及搜索筛选 JSON
│   │   ├── VideoDetail/ Comments/   # 视频详情和评论
│   │   ├── Account/ Settings/       # 用户中心和设置
│   │   └── ...
│   ├── Player/                      # KSPlayer 桥接、本地播放和播放器观察器
│   ├── Assets.xcassets/             # 图片和应用图标
│   ├── Info.plist
│   └── Han1meViewer.entitlements
├── project.yml                      # XcodeGen 工程配置
├── build.gradle.kts                 # Gradle 构建脚本
└── gradle/libs.versions.toml        # 依赖版本目录
```
