# 从源码构建

> 想直接装上设备使用的话，请看仓库 [README](../README.md#-安装) 的「安装」章节，下载未签名 IPA 自签即可。本页面是给想从源码自己构建的开发者看的。

## 开发环境

- **Xcode** 26.0+（iOS 16.0+ Deployment Target）
- **JDK** 21+（Gradle 9.4.1 构建 KMP 框架）
- **Kotlin** 2.3.21
- **Swift** 5.0
- **iOS 设备 / 模拟器**：iOS 16+；iOS 18+ / iOS 26+ 会启用更高版本独有 API（如 `Tab(role: .search)`、tab-bar minimize、`onScrollGeometryChange` 等）

## 启动流程

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

## CI

GitHub Actions 工作流位于 `.github/workflows/`：

- **`ios-app-build.yml`**：每次 push / PR 触发
  - `:shared:jvmTest` 跑 KMP 共享层单元测试
  - `xcodebuild` 构建 Debug 配置的未签名 IPA（artifact 90 天可下载）
- **`release.yml`**：推 `v*` tag 或手动触发
  - 构建 Release 配置的未签名 IPA
  - 打包对应 commit 的源码归档（满足 GPL-3.0 §6 要求）
  - 创建 GitHub Release 并附 IPA + 源码 + LICENSE
