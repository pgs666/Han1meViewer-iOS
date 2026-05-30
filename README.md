# Han1meViewer iOS

> 基于 Kotlin Multiplatform + SwiftUI 的 iOS 移植版本

[![Stars](https://img.shields.io/github/stars/pgs666/Han1meViewer-iOS?style=flat&logo=github&color=yellow)](https://github.com/pgs666/Han1meViewer-iOS/stargazers)
[![Forks](https://img.shields.io/github/forks/pgs666/Han1meViewer-iOS?style=flat&logo=github&color=blue)](https://github.com/pgs666/Han1meViewer-iOS/network/members)
[![License](https://img.shields.io/github/license/pgs666/Han1meViewer-iOS?style=flat&color=green)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/pgs666/Han1meViewer-iOS?style=flat&logo=git)](https://github.com/pgs666/Han1meViewer-iOS/commits/main)
[![CI](https://img.shields.io/github/actions/workflow/status/pgs666/Han1meViewer-iOS/ios-app-build.yml?branch=main&style=flat&logo=github-actions&label=build)](https://github.com/pgs666/Han1meViewer-iOS/actions/workflows/ios-app-build.yml)

[Han1meViewer](https://github.com/misaka10032w/Han1meViewer) Android Fork 的 iOS 移植版本。技术栈：Kotlin Multiplatform（共享业务、网络、解析、数据库）+ SwiftUI（原生 iOS UI）+ KSPlayer（自定义控件层）。功能上对齐 Android 上游：浏览、搜索、评论、收藏 / 订阅、下载、本地播放等。

## 文档

- [✨ 功能列表](docs/FEATURES.md) — 完整功能清单 + 路线图
- [🏗️ 技术架构](docs/ARCHITECTURE.md) — 技术栈、架构图、目录结构
- [🛠️ 构建与安装](docs/BUILDING.md) — 开发环境、启动流程、自签上机、CI
- [🐛 问题反馈](docs/REPORTING_ISSUES.md) — 如何提交 Issue、收集崩溃 / 诊断日志
- [⚠️ 已知问题](docs/known-issues/README.md)
- [📜 项目来源与鸣谢](docs/CREDITS.md) — 上游溯源、特别鸣谢、许可证缘由

## 快速开始

```bash
git clone https://github.com/pgs666/Han1meViewer-iOS.git
cd Han1meViewer-iOS
brew install xcodegen && xcodegen generate
./gradlew :shared:embedAndSignAppleFrameworkForXcode
# 用 Xcode 打开生成的 .xcodeproj 运行
```

> 不打算上 App Store。设备上跑的话从 [Actions](https://github.com/pgs666/Han1meViewer-iOS/actions) 下载未签名 IPA，用 Impactor / AltStore / Sideloadly 等自签即可。详见 [构建与安装](docs/BUILDING.md)。

## 许可证

本项目采用 [GNU General Public License v3.0](LICENSE)。本项目依赖 [KSPlayer](https://github.com/kingslay/KSPlayer)（GPL-3.0），整体作品采用 GPL-3.0;上游 Apache-2.0 部分代码归属于 [YenalyLiew](https://github.com/YenalyLiew) 与 [misaka10032w](https://github.com/misaka10032w)。完整说明见 [项目来源与鸣谢](docs/CREDITS.md)。

## 免责声明

本应用程序与 `https://hanime1.me/` 及其关联方无任何隶属、合作或授权关系。

- 本应用仅获取目标网站公开显示的 DOM 结构信息，不涉及用户隐私数据或后端数据库访问
- 所有内容仅用于技术研究学习和移动端用户体验优化，不得用于非法用途
- 原始视频/图文内容版权均归原站或原始制作/发行方所有，本应用不存储、不修改、不声称拥有任何版权内容
- 使用产生的一切后果由用户自行承担

---

[![Star History Chart](https://api.star-history.com/svg?repos=pgs666/Han1meViewer-iOS&type=Date)](https://star-history.com/#pgs666/Han1meViewer-iOS&Date)
