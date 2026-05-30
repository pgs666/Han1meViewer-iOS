# 构建与安装

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

## 自签上机

由于本项目无意走 App Store 分发，安装到非开发用 iOS 设备需要自签。推荐使用 **[Impactor](https://github.com/claration/Impactor)** 给 GitHub Actions 产出的未签名 IPA 重签：

1. 从本仓库 [Actions](https://github.com/pgs666/Han1meViewer-iOS/actions) 下载最新一次成功 build 的 `Han1meViewer-unsigned-ipa` artifact
2. 用 Impactor 配合自己的 Apple ID 重签并安装到设备

> 这里只是个人偏好的推荐，任何能给 IPA 重签的工具（AltStore、Sideloadly、原生开发者签名等）原则上都可以用。

## CI

GitHub Actions 工作流：`.github/workflows/ios-app-build.yml`

- `:shared:jvmTest` 跑 KMP 共享层单元测试
- `xcodebuild` 构建未签名 IPA（产物 artifact 可下载）
