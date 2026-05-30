# 项目来源与鸣谢

本项目是 [Han1meViewer](https://github.com/misaka10032w/Han1meViewer) 的 iOS 移植版本。

## 上游溯源

| 项目 | 作者 | 说明 |
|------|------|------|
| [YenalyLiew/Han1meViewer](https://github.com/YenalyLiew/Han1meViewer) | Yenaly Liew | 原始 Android 项目，采用 Apache License 2.0 |
| [misaka10032w/Han1meViewer](https://github.com/misaka10032w/Han1meViewer) | misaka10032w | Android Fork 版本，本项目的上游 |
| **本项目** | pgs666 | iOS 移植版本 |

## 特别鸣谢

- **[YenalyLiew](https://github.com/YenalyLiew)** — 原始 Han1meViewer 的作者，奠定了整个项目的基础架构、HTML 解析逻辑和核心功能设计
- **[misaka10032w](https://github.com/misaka10032w)** — Android Fork 版本的维护者，在原版基础上新增了诸多功能（评论系统、下载管理、HKeyframe、打卡系统、隐私保护等），本项目的业务逻辑和解析规则主要参照此版本
- **Kotlin Multiplatform 生态** — [Ktor](https://ktor.io/)、[SQLDelight](https://cashapp.github.io/sqldelight/)、[Ksoup](https://github.com/fleeksoft/ksoup) 等优秀的 KMP 库
- **iOS 端依赖** — [KSPlayer](https://github.com/kingslay/KSPlayer)（视频播放，GPL-3.0）、[Nuke](https://github.com/kean/Nuke)（图片加载）

## 关于许可证

原始 Android 项目采用 Apache License 2.0。但本 iOS 移植版本依赖 [KSPlayer](https://github.com/kingslay/KSPlayer)，KSPlayer 采用 **GPL-3.0** 许可证；GPL-3.0 是强 copyleft 许可证，要求与之静态/动态链接的整体作品也以 GPL-3.0（或兼容许可证）发布。Apache-2.0 单向兼容 GPL-3.0，因此本项目的整体作品采用 **GPL-3.0** 许可证（保留对原始 Apache-2.0 部分代码的归属）。

主要条款：

- 允许商用、修改、分发
- 要求保留版权声明和许可证文件
- 派生作品 / 与本项目静态或动态链接的作品 必须 同样采用 GPL-3.0（或兼容许可证）发布
- 必须随二进制提供完整对应的源码（或以书面形式承诺提供）
- 不提供质量担保
- 不承担用户使用风险

许可证文件：[LICENSE](../LICENSE)（GNU General Public License v3.0）

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

部分代码继承自上游 Apache-2.0 项目，归属于 Yenaly 与 misaka10032w。
