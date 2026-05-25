# Han1meViewer iOS

> 基于 Kotlin Multiplatform + SwiftUI 的 iOS 移植版本

## 📜 项目来源与鸣谢

本项目是 [Han1meViewer](https://github.com/misaka10032w/Han1meViewer) 的 iOS 移植版本。

**原项目溯源：**

| 项目 | 作者 | 说明 |
|------|------|------|
| [YenalyLiew/Han1meViewer](https://github.com/YenalyLiew/Han1meViewer) | Yenaly Liew | 原始 Android 项目，采用 Apache License 2.0 |
| [misaka10032w/Han1meViewer](https://github.com/misaka10032w/Han1meViewer) | misaka10032w | Android Fork 版本，本项目的上游 |
| **本项目** | — | iOS 移植版本 |

**特别鸣谢：**
- **[YenalyLiew](https://github.com/YenalyLiew)** — 原始 Han1meViewer 的作者，奠定了整个项目的基础架构、HTML 解析逻辑和核心功能设计
- **[misaka10032w](https://github.com/misaka10032w)** — Android Fork 版本的维护者，在原版基础上新增了诸多功能（评论系统、下载管理、HKeyframe、打卡系统、隐私保护等），本项目的业务逻辑和解析规则主要参照此版本
- **Kotlin Multiplatform 生态** — [Ktor](https://ktor.io/)、[SQLDelight](https://cashapp.github.io/sqldelight/)、[Ksoup](https://github.com/nickhall-yk/ksoup) 等优秀的 KMP 库，使跨平台共享业务逻辑成为可能
- **SwiftUI 社区** — [Nuke](https://github.com/kean/Nuke) 图片加载库

根据 Apache License 2.0 要求：
- 保留原版权声明
- 包含许可证文件副本
- 说明修改内容

**许可证文件：** [LICENSE](LICENSE)

---

## 🏗️ 技术架构

```
┌─────────────────────────────────────────────┐
│                 iosApp (SwiftUI)             │
│  Views · ViewModels · Snapshots (DTO)       │
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

| 层级 | 技术栈 | 说明 |
|------|--------|------|
| 共享业务层 | Kotlin Multiplatform | 模型、网络、解析、数据库、业务逻辑 |
| 网络 | Ktor 3.x + Darwin Engine | HTTP 客户端，自动 Cookie 管理 |
| HTML 解析 | Ksoup | 多平台 Jsoup 替代方案 |
| 本地存储 | SQLDelight | 类型安全的 SQLite，iOS 使用 Native 驱动 |
| 表现层 | SwiftUI | 原生 iOS UI，MVVM 架构 |
| 图片加载 | Nuke | 异步图片加载与缓存 |
| 构建 | XcodeGen + Gradle | `project.yml` 生成 Xcode 工程，Gradle 构建 KMP 框架 |

---

## ✨ 已实现功能

| 功能 | 状态 | 说明 |
|------|------|------|
| 首页浏览 | ✅ | Banner 跳转、分类视频轮播、下拉刷新 |
| 搜索 | ✅ | 全部筛选项（类型/排序/标签/品牌/时长/日期）、搜索历史、分页 |
| 视频详情 | ✅ | 作者卡片、标签、收藏/稍后观看、系列影片、相关影片 |
| 视频播放 | ✅ | AVPlayer、清晰度切换、全屏播放、方向自适应 |
| 关注/订阅 | ✅ | 艺术家卡片、订阅视频列表、分页 |
| 收藏列表 | ✅ | 查看、删除 |
| 稍后观看 | ✅ | 查看、删除 |
| 播放列表 | ✅ | 列表查看、详情视频列表 |
| 在线观看历史 | ✅ | 排序（最新/最早）、删除 |
| 本地观看历史 | ✅ | 自动记录、删除、清空 |
| 登录 | ✅ | WKWebView 登录页、Cookie 导入、登出 |
| Cloudflare 验证 | ✅ | 自动检测、WebView 手动验证 |
| 设置 | ✅ | 清除搜索历史、观看历史、缓存 |

### 待实现

| 功能 | 说明 |
|------|------|
| 评论 | 评论列表、回复、排序、举报 |
| 月度预览 | 月度新番日历 |
| 用户账户页 | 个人资料详情展示 |
| 收藏/播放列表写入 | 添加到收藏、添加到播放列表 |

---

## 🛠️ 开发环境

- **Xcode** 26.0+（iOS 15.0+ Deployment Target）
- **JDK** 21+（Gradle 9.4.1 构建 KMP 框架）
- **Kotlin** 2.3.21
- **Swift** 5.0

### 启动流程

1. 克隆项目：

   ```bash
   git clone https://github.com/<your-username>/Han1meViewer-iOS.git
   cd Han1meViewer-iOS
   ```

2. 生成 Xcode 工程（需安装 XcodeGen）：

   ```bash
   brew install xcodegen
   xcodegen generate
   ```

3. 构建 KMP 框架：

   ```bash
   ./gradlew :shared:embedAndSignAppleFrameworkForXcode
   ```

4. 用 Xcode 打开生成的 `.xcodeproj`，选择模拟器或设备运行。

> Xcode 的 Pre-build Script 会自动执行 Gradle 构建，首次编译可能较慢。

---

## 📂 项目结构

```
Han1meViewer-iOS/
├── shared/                          # KMP 共享模块
│   └── src/commonMain/kotlin/com/yenaly/han1meviewer/shared/
│       ├── model/                   # 数据模型（@Serializable）
│       ├── repository/              # 网络仓库（Ktor 实现）
│       ├── parser/                  # HTML 解析器（Ksoup）
│       ├── network/                 # HTTP 客户端配置
│       ├── session/                 # Cookie 会话管理
│       ├── db/                      # SQLDelight 数据库
│       ├── app/                     # 依赖注入容器
│       ├── home/ search/ video/     # 功能模块（Feature + Snapshot）
│       ├── following/ userlist/ playlist/ history/ auth/
│       └── ...
├── iosApp/                          # SwiftUI iOS 应用
│   ├── Han1meViewerApp.swift        # 入口、Tab 栏
│   ├── *View.swift                  # 视图层
│   ├── *ViewModel.swift             # 视图模型
│   ├── SearchOptions/               # 搜索筛选 JSON 数据
│   └── ...
├── project.yml                      # XcodeGen 工程配置
├── build.gradle.kts                 # Gradle 构建脚本
└── gradle/libs.versions.toml        # 依赖版本目录
```

---

## 📄 许可证

本项目继承原始项目的 [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)，主要条款包括：
- 允许商用、修改、分发
- 要求保留版权声明和许可证文件
- 提供修改说明（如有）
- 不提供质量担保
- 不承担用户使用风险

完整条款请参阅项目根目录下的 [LICENSE](LICENSE) 文件。

---

## ⚖️ 免责声明

本应用程序与 `https://hanime1.me/` 及其关联方无任何隶属、合作或授权关系。

- 本应用仅获取目标网站公开显示的 DOM 结构信息，不涉及用户隐私数据或后端数据库访问
- 所有内容仅用于技术研究学习和移动端用户体验优化，不得用于非法用途
- 原始视频/图文内容版权均归原站或原始制作/发行方所有，本应用不存储、不修改、不声称拥有任何版权内容
- 使用产生的一切后果由用户自行承担
