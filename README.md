# Han1meViewer iOS

> 基于 Kotlin Multiplatform + SwiftUI 的 iOS 移植版本

## 📜 项目来源与鸣谢

本项目是 [Han1meViewer](https://github.com/misaka10032w/Han1meViewer) 的 iOS 移植版本。

**原项目溯源：**

| 项目 | 作者 | 说明 |
|------|------|------|
| [YenalyLiew/Han1meViewer](https://github.com/YenalyLiew/Han1meViewer) | Yenaly Liew | 原始 Android 项目，采用 Apache License 2.0 |
| [misaka10032w/Han1meViewer](https://github.com/misaka10032w/Han1meViewer) | misaka10032w | Android Fork 版本，本项目的上游 |
| **本项目** | pgs666 | iOS 移植版本 |

**特别鸣谢：**
- **[YenalyLiew](https://github.com/YenalyLiew)** — 原始 Han1meViewer 的作者，奠定了整个项目的基础架构、HTML 解析逻辑和核心功能设计
- **[misaka10032w](https://github.com/misaka10032w)** — Android Fork 版本的维护者，在原版基础上新增了诸多功能（评论系统、下载管理、HKeyframe、打卡系统、隐私保护等），本项目的业务逻辑和解析规则主要参照此版本
- **Kotlin Multiplatform 生态** — [Ktor](https://ktor.io/)、[SQLDelight](https://cashapp.github.io/sqldelight/)、[Ksoup](https://github.com/fleeksoft/ksoup) 等优秀的 KMP 库
- **iOS 端依赖** — [KSPlayer](https://github.com/kingslay/KSPlayer)（视频播放）、[Nuke](https://github.com/kean/Nuke)（图片加载）

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

| 层级 | 技术栈 | 说明 |
|------|--------|------|
| 共享业务层 | Kotlin Multiplatform | 模型、网络、解析、数据库、业务逻辑 |
| 网络 | Ktor 3.x + Darwin Engine | HTTP 客户端，自动 Cookie 管理，419 自动 refresh + retry |
| HTML 解析 | Ksoup | 多平台 Jsoup 替代方案 |
| 本地存储 | SQLDelight | 类型安全的 SQLite，iOS 使用 Native 驱动 |
| 视频播放 | KSPlayer | 自定义控件层，支持手势、长按倍速、清晰度切换、续播 |
| 表现层 | SwiftUI | 原生 iOS UI，MVVM 架构（iOS 16/17/18+ 分别走最佳 API） |
| 图片加载 | Nuke (NukeUI) | 异步加载、缓存、自适应图像尺寸 |
| 构建 | XcodeGen + Gradle | `project.yml` 生成 Xcode 工程，Gradle 构建 KMP 框架 |

---

## ✨ 已实现功能

### 浏览与发现
| 功能 | 状态 | 说明 |
|------|------|------|
| 首页 | ✅ | Banner 自适应宽高比、分类视频轮播、下拉刷新、**栏目排序自定义** |
| 搜索 | ✅ | 全部筛选项（类型/排序/标签/品牌/时长/日期）、搜索历史、分页、iOS 26+ tab-bar 内联搜索 |
| 关注/订阅 | ✅ | 艺术家头像点击进入作者页、订阅视频列表、分页 |
| 标签 / 作者 / 栏目"更多" | ✅ | 统一推送独立宫格视频列表，不再切换到搜索 tab |

### 视频详情
| 功能 | 状态 | 说明 |
|------|------|------|
| 详情页 | ✅ | 作者卡片、标签、收藏/稍后观看、系列影片、相关影片、宫格相关推荐 |
| 简介 / 评论切换 | ✅ | 横滑切换、Bilibili 风格的 sticky-top 播放器 + 跟手收缩 |
| 评论 | ✅ | 楼主评论、回复、点赞、举报 |

### 视频播放（KSPlayer）
| 功能 | 状态 | 说明 |
|------|------|------|
| 自定义控件 | ✅ | 顶部栏（返回、静音、画面比例、收起）+ 底部栏（播放/暂停、进度条、倍速、画质、全屏）|
| 全屏 | ✅ | 双指捏合 / 按钮触发；竖屏视频可强制保持竖屏（设置可关）|
| 手势 | ✅ | 横滑跳转进度、左半屏滑动调亮度、右半屏滑动调音量、长按倍速 boost |
| 进度续播 | ✅ | 上次播放位置精确续播；用户拖回的进度也会持久化 |
| 清晰度切换 | ✅ | 多源自动切换菜单（解析有多源时显示）|
| 边缘安全区 | ✅ | 上下左右安全区不响应播放手势，避让系统手势（swipe-back / Control Center / Home Indicator）|

### 用户列表
| 功能 | 状态 | 说明 |
|------|------|------|
| 收藏列表 | ✅ | 查看、删除、下拉刷新 |
| 稍后观看 | ✅ | 查看、删除、下拉刷新 |
| 播放清单 | ✅ | 列表查看、详情视频列表 |
| 在线观看历史 | ✅ | 排序（最新/最早）、删除 |
| 本地观看历史 | ✅ | 自动记录、删除、清空 |

### 账号 / 安全
| 功能 | 状态 | 说明 |
|------|------|------|
| 登录 | ✅ | WKWebView 登录页、Cookie 同步导入、登出 |
| Cloudflare 验证 | ✅ | 自动检测、WebView 手动验证 |
| 419 防护 | ✅ | CSRF 失效自动重新拉取 token + 重试一次；重试失败时提示"您可能需要重新登录" |

### 设置
| 项 | 默认值 | 说明 |
|------|------|------|
| 默认画质 | 1080P | 2160P / 1440P / 1080P / 720P / 480P / 360P |
| 字幕语言 | 繁体中文 | 繁体 / 简体 / 日文 / 英文 |
| 长按倍速 | 2.0x | 1.0x ~ 3.0x，0.25 步进 |
| 自动恢复播放进度 | 开 | 进入视频后跳到上次播放位置 |
| 打开视频时自动播放 | 开 | 关闭后进详情页保持暂停 |
| 竖屏视频不强制横屏 | 开 | 关闭后所有视频全屏均强制横屏 |
| 显示已看标记 | 开 | 列表上的"已观看"角标 |
| 底部进度条 | 开 | 视频卡片底部细线进度 |
| 首页栏目排序 | — | 拖把手即时调整首页栏目顺序 |
| 数据清理 | — | 搜索历史、观看历史、缓存 |

### 待实现 / 路线图
| 功能 | 说明 |
|------|------|
| 月度预览 | 月度新番日历 |
| 用户账户页 | 个人资料详情展示 |
| 手动 Cookie 导入 | 独立输入 Cookie 登录 |
| QR Cookie 导入 | 扫码导入 Cookie 登录 |
| 视频下载 | 离线缓存 |

---

## 🛠️ 开发环境

- **Xcode** 26.0+（iOS 16.0+ Deployment Target）
- **JDK** 21+（Gradle 9.4.1 构建 KMP 框架）
- **Kotlin** 2.3.21
- **Swift** 5.0
- **iOS 设备 / 模拟器**：iOS 16+；iOS 18+ / iOS 26+ 会启用更高版本独有 API（如 `Tab(role: .search)`、tab-bar minimize、`onScrollGeometryChange` 等）

### 启动流程

1. 克隆项目：

   ```bash
   git clone https://github.com/pgs666/Han1meViewer-iOS.git
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

### CI

- GitHub Actions 工作流：`.github/workflows/ios-app-build.yml`
  - `:shared:jvmTest` 跑 KMP 共享层单元测试
  - `xcodebuild` 构建未签名 IPA（产物 artifact 可下载）

---

## 📂 项目结构

```
Han1meViewer-iOS/
├── shared/                          # KMP 共享模块
│   └── src/commonMain/kotlin/com/yenaly/han1meviewer/shared/
│       ├── model/                   # 数据模型（@Serializable）
│       ├── repository/              # 网络仓库（Ktor 实现，419 自动 refresh）
│       ├── parser/                  # HTML 解析器（Ksoup，过滤 add/remove 等噪声 anchor）
│       ├── network/                 # HTTP 客户端配置 + cookie 处理
│       ├── session/                 # Cookie 会话管理（含 Darwin Set-Cookie 拆分）
│       ├── db/                      # SQLDelight 数据库 + migrations
│       ├── app/                     # 依赖注入容器
│       ├── home/ search/ video/     # 功能模块（Feature + Snapshot）
│       ├── following/ userlist/ playlist/ history/ auth/
│       └── ...
├── iosApp/                          # SwiftUI iOS 应用
│   ├── Han1meViewerApp.swift        # 入口、Tab 栏（modern + legacy 双轨）
│   ├── KSPlayerView.swift           # KSPlayer 自定义控件层（手势、HUD、清晰度等）
│   ├── VideoDetailView.swift        # 视频详情主体（sticky-top + 跟手收缩 + 简介/评论）
│   ├── HomeView.swift               # 首页（栏目排序应用层）
│   ├── HomeSectionOrderView.swift   # 首页栏目排序设置子页
│   ├── ArtistVideosView.swift       # 通用宫格搜索结果（标签/作者/首页栏目共用）
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
