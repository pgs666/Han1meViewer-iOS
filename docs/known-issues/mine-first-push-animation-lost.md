# 切换到「我的」后立即进入子页时丢失 push 转场动画

状态：**未解决（待未来 UIKit 导航重构）**。仅影响动画观感，功能完全正常。

## 现象

启动 App（默认停在「首页」）后，**切换到「我的」标签并在头几秒内立即点击其子页**（设置 / 下载 / 收藏 / 在线历史 / 本地历史 / 播放清单）时，目标页**瞬间出现，没有从右向左滑入的 push 转场动画**。

- 在「我的」停留几秒后再点击 → 动画正常。
- 「首页」「关注」的子页 → 从不丢失动画。
- 仅在 **iOS 17 及以上**复现；**iPadOS 16.6.1 不复现**。
- 复现机型示例：iPhone 15 Pro。

## 为什么只有「我的」

「我的」的菜单是**静态列表，进入后立即可点**；而「首页」「关注」需要先完成网络加载才能点到子页，那时该标签的 `NavigationStack` 已经「安定」，早已错过出问题的时间窗口。所以这不是「我的」特有的逻辑问题——任何「切换过去后能立刻 push」的标签都会触发，「我的」只是唯一满足这个条件的页面。

## 根因（已定位到层级，无应用层解法）

根因在 SwiftUI `TabView`（iOS 17+ 新实现）对「**懒加载的标签首次出现、尚未安定时立即 push**」的原生行为：此时发起的 `NavigationStack` push 不带转场动画，直到标签视图安定。

iPadOS 16 不复现，是因为 iOS 16 的 `TabView`/`NavigationStack` 是不同的旧实现。

## 已排除的因素（通过逐一隔离构建验证，均无效）

- 登录检查的异步状态更新、检查指示（spinner / 文字）、`disablesAnimations` 事务
- `MineViewModel` 的持有位置（移出 `MineView`、移到子视图）
- 账号卡：放在 `List` 内 / 移到 `.safeAreaInset` / **整个移除**（仍丢）
- 头像 `LazyImage` 异步加载
- 首页启动加载（延迟 5 秒仍丢）
- `MineView` 内容（精简到只剩一个 `NavigationLink` 仍丢）
- `CompatibleNavigationStack` / `ObservedNavigationStack` 封装（改为纯 `NavigationStack` 仍丢）
- 观察共享的 `TabBarVisibilityController`
- `.popsToRootWhen` 的 `UIViewControllerRepresentable`（移除仍丢；且「点标签回根」是系统自带行为，与它无关）
- 自定义 `tabSelection` Binding（改为朴素 `$selectedTab` 仍丢）
- tab bar 隐藏机制（iOS 17+ 改用与 iPadOS 16 相同的「目标页本地 `.toolbar(.hidden, for: .tabBar)`」仍丢）

> 这一长串排除把根因收敛到了「`TabView` + 懒加载标签 + 首次 push」这一系统层组合，应用层改动无法解决。

## 顺带修复并保留的改进

排查中发现并**保留**了一个独立的正确改进（与本问题无关）：`SettingsView` 的偏好控件之前用硬编码默认值初始化、再由 `.task` 里的 `loadPreferences()` 覆盖，导致首次打开设置时滑块从默认值「跳」到真实值。现改为在 `init` 中用 `State(initialValue:)` 直接以真实存储值初始化，首帧即正确，且少一次重算。

## 后续

待将来把导航层迁移到 UIKit 承载的容器（与 nav-bar 标题问题同批重构）后，可由 UIKit 直接控制 push 转场，从根本上消除此问题。
