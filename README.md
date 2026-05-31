# Han1meViewer iOS

**简体中文** | [English](README.en.md)

> 基于 Kotlin Multiplatform + SwiftUI 的 iOS 移植版本

[![Stars](https://img.shields.io/github/stars/pgs666/Han1meViewer-iOS?style=flat&logo=github&color=yellow)](https://github.com/pgs666/Han1meViewer-iOS/stargazers)
[![Forks](https://img.shields.io/github/forks/pgs666/Han1meViewer-iOS?style=flat&logo=github&color=blue)](https://github.com/pgs666/Han1meViewer-iOS/network/members)
[![License](https://img.shields.io/github/license/pgs666/Han1meViewer-iOS?style=flat&color=green)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/pgs666/Han1meViewer-iOS?style=flat&logo=git)](https://github.com/pgs666/Han1meViewer-iOS/commits/main)
[![CI](https://img.shields.io/github/actions/workflow/status/pgs666/Han1meViewer-iOS/ios-app-build.yml?branch=main&style=flat&logo=github-actions&label=build)](https://github.com/pgs666/Han1meViewer-iOS/actions/workflows/ios-app-build.yml)

[Han1meViewer](https://github.com/misaka10032w/Han1meViewer) Android Fork 的 iOS 移植版本。技术栈：Kotlin Multiplatform（共享业务、网络、解析、数据库）+ SwiftUI（原生 iOS UI）+ KSPlayer（自定义控件层）。功能上对齐 Android 上游：浏览、搜索、评论、收藏 / 订阅、下载、本地播放等。

## 📜 项目来源与鸣谢

| 项目 | 作者 | 说明 |
|------|------|------|
| [YenalyLiew/Han1meViewer](https://github.com/YenalyLiew/Han1meViewer) | Yenaly Liew | 原始 Android 项目，采用 Apache License 2.0 |
| [misaka10032w/Han1meViewer](https://github.com/misaka10032w/Han1meViewer) | misaka10032w | Android Fork 版本，本项目的上游 |
| **本项目** | pgs666 | iOS 移植版本 |

特别鸣谢：

- **[YenalyLiew](https://github.com/YenalyLiew)** — 原始 Han1meViewer 的作者，奠定了整个项目的基础架构、HTML 解析逻辑和核心功能设计
- **[misaka10032w](https://github.com/misaka10032w)** — Android Fork 版本的维护者，在原版基础上新增了诸多功能（评论系统、下载管理、HKeyframe、打卡系统、隐私保护等），本项目的业务逻辑和解析规则主要参照此版本
- **Kotlin Multiplatform 生态** — [Ktor](https://ktor.io/)、[SQLDelight](https://cashapp.github.io/sqldelight/)、[Ksoup](https://github.com/fleeksoft/ksoup) 等优秀的 KMP 库
- **iOS 端依赖** — [KSPlayer](https://github.com/kingslay/KSPlayer)（视频播放，GPL-3.0）、[Nuke](https://github.com/kean/Nuke)（图片加载）

## 📚 文档

- [✨ 功能列表](docs/FEATURES.md) — 完整功能清单 + 路线图
- [🏗️ 技术架构](docs/ARCHITECTURE.md) — 技术栈、架构图、目录结构
- [🛠️ 从源码构建](docs/BUILDING.md) — 开发环境、启动流程、CI
- [⚠️ 已知问题](docs/known-issues/README.md)

## 📲 安装

本项目不走 App Store 分发，安装到非开发用 iOS 设备需要**自签**。

获取未签名 IPA：

- **稳定版**：[Releases](https://github.com/pgs666/Han1meViewer-iOS/releases) 页下载最新版本的 `Han1meViewer-X.Y.Z-unsigned.ipa`
- **最新构建**：[Actions](https://github.com/pgs666/Han1meViewer-iOS/actions) 里最近一次成功 build 的 `Han1meViewer-unsigned-ipa` artifact

任何能给 IPA 重签的工具都可以使用：[Impactor](https://github.com/claration/Impactor)、AltStore、Sideloadly、原生 Xcode 开发者签名等。配上自己的 Apple ID 重签后即可安装到设备。

> 如果你的设备支持 [TrollStore](https://github.com/opa334/TrollStore)，也可以直接用它安装未签名 IPA，免重签、永久有效。

> 想从源码自己构建的开发者请看 [docs/BUILDING.md](docs/BUILDING.md)。

## 🐛 问题反馈

遇到任何问题、Bug 或有功能建议，欢迎到 [GitHub Issues](https://github.com/pgs666/Han1meViewer-iOS/issues) 提交。提交时请尽量描述清楚复现步骤、设备型号与系统版本。

### 闪退：附上系统崩溃日志

iOS 会自动记录每次崩溃的诊断日志，附上它能极大帮助定位问题：

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

- **应用内导出**：设置 → 诊断日志 → 「导出 / 分享日志」，直接分享给自己或存到文件
- **从「文件」App 取**：打开**文件**App → **我的 iPhone/iPad** → **Han1meViewer** → **Logs** 文件夹，里面的 `app.log` 即是

> 诊断日志默认开启，可在 设置 → 诊断日志 中关闭或清除。日志只保存在本机，会自动按大小滚动并清理（保留约 7 天），不会自动上传。

## 📄 许可证

本项目采用 [GNU General Public License v3.0](LICENSE)。本项目依赖 [KSPlayer](https://github.com/kingslay/KSPlayer)（GPL-3.0），整体作品采用 GPL-3.0；上游 Apache-2.0 部分代码归属于 Yenaly 与 misaka10032w。

主要条款：允许商用 / 修改 / 分发；要求保留版权声明；派生作品 / 与本项目静态或动态链接的作品必须同样采用 GPL-3.0（或兼容许可证）发布；必须随二进制提供完整对应源码；不提供质量担保。完整条款见 [LICENSE](LICENSE)。

## ⚖️ 免责声明

本应用程序与 `https://hanime1.me/` 及其关联方无任何隶属、合作或授权关系。

- 本应用仅获取目标网站公开显示的 DOM 结构信息，不涉及用户隐私数据或后端数据库访问
- 所有内容仅用于技术研究学习和移动端用户体验优化，不得用于非法用途
- 原始视频/图文内容版权均归原站或原始制作/发行方所有，本应用不存储、不修改、不声称拥有任何版权内容
- 使用产生的一切后果由用户自行承担

---

[![Star History Chart](https://api.star-history.com/svg?repos=pgs666/Han1meViewer-iOS&type=Date)](https://star-history.com/#pgs666/Han1meViewer-iOS&Date)
