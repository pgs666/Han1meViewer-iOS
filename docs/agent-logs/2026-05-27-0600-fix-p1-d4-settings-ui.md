# 修复 P1-D4：偏好设置不足

日期：2026-05-27 06:00 CST

## 背景

P1-D4 是 review-ios-vs-android-round2.md 中最后一个未修复项。Android 版有完整的设置页面
（画质、字幕语言、播放速度、恢复播放进度、已看标记、底部进度条等），iOS 版缺失。

## 改动

### 1. PreferencesStore 跨平台基础设施（3 个新文件）

- `shared/.../preferences/PreferencesStore.kt`：`PreferencesStore` 类 + 非泛型具体类型类
  - `StringPreferenceItem`、`FloatPreferenceItem`、`BooleanPreferenceItem`
  - 每个类有 `get(): T`、`set(value: T)`、`flow: Flow<T>`
- `shared/.../preferences/IosPreferencesStorage.kt`：`UserDefaults` 实现
- `shared/.../preferences/JvmPreferencesStorage.kt`：内存测试实现

### 2. SharedAppEnvironment 集成

- 构造器新增 `preferencesStorage: PreferencesStorage` 参数
- 暴露 `preferences(): PreferencesStore` 方法

### 3. SettingsView UI

- 新增"播放设置"section：画质选择、字幕语言、播放速度滑块、自动恢复播放进度开关
- 新增"界面"section：已看标记开关、底部进度条开关
- 使用 `onValueChange(of:perform:)` 兼容 iOS 15+（避免 iOS 17+ 的 `onChange` 新语法）
- 将 body 拆分为 6 个子视图计算属性，解决 Swift 编译器 type-check 超时

## 修复的 CI 错误

1. **泛型擦除问题**：`PreferenceItem<T>` 的 `get()` 在 Swift 中返回 `NSString?`/`KotlinFloat?`/`KotlinBoolean?`
   → 替换为非泛型具体类型类
2. **参数标签**：Kotlin 函数参数名导出为 Swift argument label，`.set(newValue)` → `.set(value: newValue)`
3. **iOS 版本**：`onChange(of:) { _, newValue in }` 需要 iOS 17+，项目部署目标 iOS 15.0
   → 使用 `onValueChange(of:perform:)` 兼容层
4. **编译器超时**：body 表达式过于复杂
   → 拆分为 6 个 `@ViewBuilder` 子视图

## 验证

- 本地 `:shared:jvmTest` 通过
- CI run 26465915167 全部通过（Build unsigned device app ✓）

## User Input

Original:

```text
目前详情页的收藏按钮是坏的，请你参考Android版本进行修复，不要生造东西
```

English translation:

```text
The favorite button on the detail page is currently broken. Please fix it by referencing the Android version. Don't invent things.
```

（注：这是上一轮用户输入的延续。本轮实际修复的是 P1-D4 偏好设置项。）
