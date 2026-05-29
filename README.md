# Han1meViewer iOS

> 基于 Kotlin Multiplatform + SwiftUI 的 iOS 移植版本

[![Stars](https://img.shields.io/github/stars/pgs666/Han1meViewer-iOS?style=flat&logo=github&color=yellow)](https://github.com/pgs666/Han1meViewer-iOS/stargazers)
[![Forks](https://img.shields.io/github/forks/pgs666/Han1meViewer-iOS?style=flat&logo=github&color=blue)](https://github.com/pgs666/Han1meViewer-iOS/network/members)
[![License](https://img.shields.io/github/license/pgs666/Han1meViewer-iOS?style=flat&color=green)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/pgs666/Han1meViewer-iOS?style=flat&logo=git)](https://github.com/pgs666/Han1meViewer-iOS/commits/main)
[![CI](https://img.shields.io/github/actions/workflow/status/pgs666/Han1meViewer-iOS/ios-app-build.yml?branch=main&style=flat&logo=github-actions&label=build)](https://github.com/pgs666/Han1meViewer-iOS/actions/workflows/ios-app-build.yml)

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
- **iOS 端依赖** — [KSPlayer](https://github.com/kingslay/KSPlayer)（视频播放，GPL-3.0）、[Nuke](https://github.com/kean/Nuke)（图片加载）

**关于许可证：**

原始 Android 项目采用 Apache License 2.0。但本 iOS 移植版本依赖 [KSPlayer](https://github.com/kingslay/KSPlayer)，KSPlayer 采用 **GPL-3.0** 许可证；GPL-3.0 是强 copyleft 许可证，要求与之静态/动态链接的整体作品也以 GPL-3.0 (或兼容许可证) 发布。Apache-2.0 单向兼容 GPL-3.0，因此本项目的整体作品采用 **GPL-3.0** 许可证（保留对原始 Apache-2.0 部分代码的归属）。

**许可证文件：** [LICENSE](LICENSE)（GNU General Public License v3.0）

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
| 视频播放 | KSPlayer | 自定义控件层，支持手势、长按倍速、清晰度切换、续播、本地文件播放 |
| 视频下载 | URLSession (background) | 后台传输、限并发、断点续传、链接过期自动重取 |
| 表现层 | SwiftUI | 原生 iOS UI，MVVM 架构（iOS 16/17/18+ 分别走最佳 API） |
| 图片加载 | Nuke (NukeUI) | 异步加载、缓存、自适应图像尺寸 |
| 诊断 | 自研 AppLogger | 脱敏操作日志，写入 Documents/Logs，Files App 可见 |
| 构建 | XcodeGen + Gradle | `project.yml` 生成 Xcode 工程，Gradle 构建 KMP 框架 |

---

## ✨ 已实现功能

### 浏览与发现
| 功能 | 说明 |
|------|------|
| 首页 | Banner 自适应宽高比、分类视频轮播、下拉刷新、**栏目顺序可自定义**（拖拽排序，立即生效） |
| 搜索 | 全部筛选项（类型 / 排序 / 标签 / 品牌 / 时长 / 日期）、搜索历史（含筛选还原）、分页；筛选摘要显示实际标签名 |
| 关注 / 订阅 | 订阅作者头像可点击进入作者页、关注更新视频列表、分页 |
| 标签 / 作者 / 栏目"更多" | 统一推送**独立宫格视频列表**页（不再跳转到搜索 tab），等高卡片布局 |

### 视频详情
| 功能 | 说明 |
|------|------|
| 详情页 | 作者卡片（可点击进作者页）、标签（可点击进标签页）、收藏 / 稍后观看 / 加入清单、系列影片、相关影片宫格 |
| 简介 / 评论 | 两个区域**横滑切换**（系列/相关影片的横向滚动条优先响应，不冲突）；Bilibili 风格 sticky-top 播放器 + 暂停时跟手收缩 |
| 评论 | 楼主评论、回复、点赞、举报 |
| 操作反馈 | 收藏 / 订阅等操作后弹 Apple Music 风格居中毛玻璃 HUD（成功/失败图标，自动消失） |

### 视频播放（KSPlayer 自定义控件）
| 功能 | 说明 |
|------|------|
| 控件布局 | 顶部栏（返回、静音、画面比例、收起）+ 底部栏（播放/暂停、进度条、倍速、画质、全屏） |
| 全屏 | 双指捏合 / 按钮触发，**进出全屏自动旋转设备**；竖屏视频可保持竖屏（设置可关）；全屏返回键只退出全屏不退出页面 |
| 手势 | 横滑跳转进度、左半屏滑亮度、右半屏滑音量、长按倍速 boost |
| 进度续播 | 在线 / 本地播放都精确续播上次位置；用户拖回的进度也会持久化 |
| 清晰度切换 | 多源切换菜单（解析出多档分辨率时显示） |
| 边缘安全区 | 上下左右安全区不响应播放手势，避让系统手势（侧滑返回 / 控制中心 / Home 指示条） |
| 触摸目标 | 所有控件按钮 ≥ 44pt 命中区域（符合 HIG） |

### 下载（后台 URLSession）
| 功能 | 说明 |
|------|------|
| 画质选择 | 详情页下载按钮弹画质选择 action sheet（复用解析出的分辨率源）；仅单源时退化为打开官方下载页 |
| 后台下载 | 基于 background URLSession，App 挂起 / 被杀后继续；限并发（默认 2，可调） |
| 断点续传 | 暂停 / 继续保留已下进度；下载链接过期失败时自动重取视频页拿新地址重试 |
| 下载管理 | 下载列表显示进度 / 状态，支持暂停继续、左滑删除 |
| 本地播放 | 点击已完成项用同一套自定义播放器播放本地文件，记忆本地播放进度 |

### 用户列表
| 功能 | 说明 |
|------|------|
| 收藏列表 / 稍后观看 | 查看、删除、下拉刷新 |
| 播放清单 | 列表查看、清单内视频列表 |
| 在线观看历史 | 排序（最新 / 最早）、删除 |
| 本地观看历史 | 自动记录、删除、清空 |

### 账号 / 安全
| 功能 | 说明 |
|------|------|
| 登录 | WKWebView 登录页、Cookie 同步导入、登出 |
| 登录状态 | 异步静默检测（不阻塞 UI），已登录信息持久化；失效时卡片内提示重新登录 |
| Cloudflare 验证 | 自动检测、WebView 手动验证 |
| 419 防护 | CSRF 失效自动重新拉取 token + 重试一次；仍失败时提示"您可能需要重新登录" |
| 二级页隐藏 tab 栏 | 所有推入的二级界面自动隐藏底部 tab 栏 |

### 诊断
| 功能 | 说明 |
|------|------|
| 操作诊断日志 | 记录页面跳转 / 关键操作 / 网络失败，**自动脱敏**（不含账号 / Cookie / Token）；按大小滚动 + 自动清理；默认开启，可在设置关闭 / 导出 / 清除；「文件」App 可见 |
| 崩溃摘要 | 捕获未处理异常并在设置页显示上次异常摘要 |

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
| 首页栏目排序 | — | 拖拽即时调整首页栏目顺序 |
| 最大同时下载数 | 2 | 1 ~ 5，超出排队 |
| 诊断日志 | 开 | 开关 / 查看大小 / 导出 / 清除 |
| 数据清理 | — | 搜索历史、观看历史、缓存 |

### 待实现 / 路线图
| 功能 | 说明 |
|------|------|
| 月度预览 | 月度新番日历 |
| 用户账户页 | 个人资料详情展示 |
| 手动 / 扫码 Cookie 导入 | 独立输入或扫码导入 Cookie 登录 |

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

### 自签上机

由于本项目无意走 App Store 分发，安装到非开发用 iOS 设备需要自签。推荐使用 **[Impactor](https://github.com/claration/Impactor)** 给 GitHub Actions 产出的未签名 IPA 重签：

1. 从本仓库 [Actions](https://github.com/pgs666/Han1meViewer-iOS/actions) 下载最新一次成功 build 的 `Han1meViewer-unsigned-ipa` artifact
2. 用 Impactor 配合自己的 Apple ID 重签并安装到设备

> 这里只是个人偏好的推荐，任何能给 IPA 重签的工具（AltStore、Sideloadly、原生开发者签名等）原则上都可以用。

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
│   ├── DownloadManager.swift        # 后台 URLSession 下载引擎（限并发/断点续传/重取）
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

---

## 🐛 问题反馈

遇到任何问题、Bug 或有功能建议，欢迎到 [GitHub Issues](https://github.com/pgs666/Han1meViewer-iOS/issues) 提交。提交时请尽量描述清楚复现步骤、设备型号与系统版本。

### 如果是闪退问题

iOS 会自动记录每次崩溃的诊断日志，附上它能极大帮助定位问题。获取方式：

1. 打开系统**设置**
2. 进入**隐私与安全性** → **分析与改进** → **分析数据**
3. 在列表里**搜索** `Han1meViewer`（或本应用名）
4. 找到**日期最新**的一条记录并点开
5. 点右上角分享按钮，**存储到文件**
6. 把保存的日志文件**上传到对应的 GitHub Issue**

> 这些分析数据仅保存在你的设备本地，需要你手动导出后附到 issue 中才会被开发者看到。

### 应用内诊断日志（推荐附上）

除了系统崩溃日志，应用自带一份**操作诊断日志**，记录页面跳转与关键操作（已自动脱敏，**不含账号、Cookie、Token 等敏感信息**），对定位非崩溃类问题（卡死、功能异常等）很有帮助。

获取方式（任选其一）：

- **应用内导出**：设置 → 诊断日志 → 「导出 / 分享日志」，直接分享给自己或存到文件。
- **从「文件」App 取**：打开**文件**App → **我的 iPhone/iPad** → **Han1meViewer** → **Logs** 文件夹，里面的 `app.log` 即是。

把日志文件附到对应的 GitHub Issue 即可。

> 诊断日志默认开启，可在 设置 → 诊断日志 中关闭或清除。日志只保存在本机，会自动按大小滚动并清理（保留约 7 天），不会自动上传。

---

## 📄 许可证

本项目采用 [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html)，主要条款包括：

- 允许商用、修改、分发
- 要求保留版权声明和许可证文件
- 派生作品 / 与本项目静态或动态链接的作品 必须 同样采用 GPL-3.0（或兼容许可证）发布
- 必须随二进制提供完整对应的源码（或以书面形式承诺提供）
- 不提供质量担保
- 不承担用户使用风险

**为什么是 GPL 而不是 Apache？** 本项目依赖 [KSPlayer](https://github.com/kingslay/KSPlayer) 作为视频播放引擎；KSPlayer 采用 GPL-3.0 许可证，链接其的整体作品必须采用 GPL-3.0。原始 Android 项目代码 (Apache-2.0) 单向兼容 GPL-3.0，因此本 iOS 移植版本以 GPL-3.0 整体发布。

完整条款请参阅项目根目录下的 [LICENSE](LICENSE) 文件。

```
Han1meViewer iOS — Copyright (C) 2026 pgs666

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
```

部分代码继承自上游 Apache-2.0 项目，归属于 Yenaly 与 misaka10032w（详见 [项目来源与鸣谢](#-项目来源与鸣谢)）。

---

## ⚖️ 免责声明

本应用程序与 `https://hanime1.me/` 及其关联方无任何隶属、合作或授权关系。

- 本应用仅获取目标网站公开显示的 DOM 结构信息，不涉及用户隐私数据或后端数据库访问
- 所有内容仅用于技术研究学习和移动端用户体验优化，不得用于非法用途
- 原始视频/图文内容版权均归原站或原始制作/发行方所有，本应用不存储、不修改、不声称拥有任何版权内容
- 使用产生的一切后果由用户自行承担

---

## 🌟 Star 历史

[![Star History Chart](https://api.star-history.com/svg?repos=pgs666/Han1meViewer-iOS&type=Date)](https://star-history.com/#pgs666/Han1meViewer-iOS&Date)
