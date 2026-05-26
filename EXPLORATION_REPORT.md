# iOS KMP 修复点精确探索报告

## 1. 错误响应也要保存 cookie

### Android 实现细节
**OkHttp 自动调用机制**（KMP shared 层）：
- **文件**: `shared/src/commonMain/kotlin/com/yenaly/han1meviewer/shared/network/Han1meHttpClient.kt:43-74`
- **关键代码**:
```kotlin
HttpResponseValidator {
    validateResponse { response ->
        if (response.isCloudflareChallenge()) {
            throw DomainException(...)
        }
        when (response.status) {
            HttpStatusCode.Unauthorized -> throw DomainException(...)
            // ... 其他错误状态
        }
    }
}
```
- **说明**: Ktor 的 `HttpResponseValidator` 在 `validateResponse` 阶段抛异常前，response 的 headers 仍可访问。异常抛出后，response body 已被消费（见第 86 行 `bodyAsText()`）。

### iOS 当前实现
**Cookie 保存位置**（所有 repository 都遵循同一模式）：
- **KtorHomeRepository.kt:22-31**
```kotlin
override suspend fun getHomePage(): HomePage {
    val response = client.get(baseUrl) {
        header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
        cookieBridge.applyStoredCookies(this)
    }
    cookieBridge.saveResponseCookies(response)  // 第 28 行：成功响应才保存
    return parser.parseHome(response.bodyAsText())
}
```

- **KtorVideoRepository.kt:24-34** (mutation 示例)
```kotlin
override suspend fun setFavorite(...) {
    // ... 构建请求
    val response = client.submitForm(...) { ... }
    cookieBridge.saveResponseCookies(response)  // 第 59 行
    requireSuccessfulMutation(response, "Failed to update favorite state.")
}
```

- **KtorCookieBridge.kt:30-36**
```kotlin
suspend fun saveResponseCookies(response: HttpResponse) {
    val cookies: List<SessionCookie> = SetCookieParser.parseAll(
        headers = response.headers.setCookieHeaders(),
        fallbackDomain = domain,
    )
    cookieHeaderProvider.saveResponseCookies(cookies)
}
```

**问题**: `saveResponseCookies()` 在 `requireSuccessfulMutation()` 之前调用，但如果异常被抛出，cookie 仍会被保存（因为 Ktor 的 validator 在 response 返回前执行）。

**iOS WebView 登录路径**:
- **LoginView.swift:267-307** - 通过 `WKHTTPCookieStore.getAllCookies()` 获取 cookies，然后调用 `webLoginFeature.importConfirmedLoginCookiesJson()`
- **CloudflareChallengeView.swift:200-249** - 通过 `importChallengeCookieHeader()` 导入 CF cookies

### 修复时需要触碰的函数/字段
- KMP: `KtorCookieBridge.saveResponseCookies()` - 需要在 validator 抛异常前调用
- KMP: `Han1meHttpClient.kt` 的 `HttpResponseValidator` 配置
- iOS: `LoginView.encodeCookiesForImport()` 函数签名（第 46-73 行）
- iOS: `CloudflareChallengeView.Coordinator.importClearanceCookies()` 的 cookie 构建逻辑（第 219-221 行）

---

## 2. WebView UA 与 Ktor UA 统一

### Android 实现细节
**Ktor UA 值**:
- **文件**: `shared/src/commonMain/kotlin/com/yenaly/han1meviewer/shared/repository/HanimeNetworkDefaults.kt:1-8`
```kotlin
object HanimeNetworkDefaults {
    const val DEFAULT_BASE_URL = "https://hanime1.me"
    const val DEFAULT_USER_AGENT =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
            "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
}
```

**Ktor 注入位置**（所有 repository 统一）:
- **KtorHomeRepository.kt:24**
```kotlin
header(HttpHeaders.UserAgent, HanimeNetworkDefaults.DEFAULT_USER_AGENT)
```
- **KtorVideoRepository.kt:26, 55, 81, 106** (mutation 也注入)
- **KtorSearchRepository.kt:27**
- **KtorUserVideoListRepository.kt:32, 44, 71**

### iOS 当前实现
**WebView UA 设置**:
- **LoginView.swift:125-137** - `WKWebView` 创建时未显式设置 UA
- **CloudflareChallengeView.swift:125-138** - 同样未设置 UA
- **iOS 默认 UA**: WKWebView 使用系统默认 UA（通常包含 Safari 标识）

**问题**: iOS WebView 的 UA 与 Ktor 的 iPhone UA 不一致，可能导致网站返回不同内容。

### 修复时需要触碰的函数/字段
- KMP: `HanimeNetworkDefaults.DEFAULT_USER_AGENT` - 常量值
- iOS: `LoginView.WebLoginView.makeUIView()` - 第 125-137 行，需要设置 `webView.customUserAgent`
- iOS: `CloudflareChallengeView.CloudflareWebView.makeUIView()` - 第 125-138 行，同样需要设置
- iOS: 需要从 KMP 暴露 UA 常量给 Swift 使用

---

## 3. CF cookie 元数据

### Android 实现细节
**CF Cookie 保存方式**:
- **文件**: `shared/src/commonMain/kotlin/com/yenaly/han1meviewer/shared/auth/CloudflareFeature.kt:11-19`
```kotlin
suspend fun importChallengeCookieHeader(cookieHeader: String, domain: String): CloudflareChallengeSnapshot {
    val cookies = parseCookieHeader(cookieHeader, domain)
    sessionStore.saveCookies(cookies)
    return CloudflareChallengeSnapshot(
        hasClearance = cookies.any { cookie -> cookie.name == CLOUDFLARE_CLEARANCE_COOKIE },
        importedCookieCount = cookies.size,
    )
}
```

**Cookie 解析**:
- **CloudflareFeature.kt:21-38** - 简单的 `;` 分割，构建 `SessionCookie` 对象
- **SessionCookie 结构**: `name`, `value`, `domain`, `secure=true`, 无 path/expires 元数据

### iOS 当前实现
**登录路径** (Web Login):
- **LoginView.swift:46-73** - `encodeCookiesForImport()` 函数
```swift
fileprivate static func encodeCookiesForImport(_ cookies: [HTTPCookie]) -> String? {
    let payload: [[String: Any]] = cookies.compactMap { cookie in
        var entry: [String: Any] = [
            "name": cookie.name,
            "value": cookie.value,
        ]
        if !cookie.domain.isEmpty {
            entry["domain"] = cookie.domain
        }
        if !cookie.path.isEmpty {
            entry["path"] = cookie.path
        }
        if let expiresDate = cookie.expiresDate {
            entry["expiresAtEpochMillis"] = Int64(expiresDate.timeIntervalSince1970 * 1000)
        }
        entry["secure"] = cookie.isSecure
        entry["httpOnly"] = cookie.isHTTPOnly
        return entry
    }
    // 返回 JSON 字符串
}
```

**CF 路径** (Cloudflare Challenge):
- **CloudflareChallengeView.swift:219-221** - 手动构建 cookie header
```swift
let cookieHeader = hanimeCookies
    .map { "\($0.name)=\($0.value)" }
    .joined(separator: "; ")
```
- **CloudflareFeature.kt:11** - 调用 `importChallengeCookieHeader(cookieHeader, domain)`

**JSON 结构** (Web Login):
```json
[
  {
    "name": "...",
    "value": "...",
    "domain": "hanime1.me",
    "path": "/",
    "expiresAtEpochMillis": 1234567890000,
    "secure": true,
    "httpOnly": false
  }
]
```

### 修复时需要触碰的函数/字段
- iOS: `LoginView.encodeCookiesForImport()` - 第 46-73 行，JSON 序列化逻辑
- iOS: `CloudflareChallengeView.Coordinator.importClearanceCookies()` - 第 219-221 行，cookie header 构建
- KMP: `CloudflareFeature.parseCookieHeader()` - 第 21-38 行，需要支持更多元数据
- KMP: `WebLoginFeature.importConfirmedLoginCookiesJson()` - 第 42-46 行，JSON 反序列化
- KMP: `WebCookiePayload` 数据类 - 第 169-194 行，定义 JSON 结构

---

## 4. parseHome HTML 级登录态

### Android 实现细节
**parseHome 返回的登录态字段**:
- **文件**: `shared/src/commonMain/kotlin/com/yenaly/han1meviewer/shared/parser/KsoupHtmlParser.kt:35-78`
```kotlin
override fun parseHome(html: String): HomePage {
    val body = parseHtml(html).body()
    val csrfToken = body.selectFirst("input[name=_token]")?.attr("value")
    val userInfo = body.selectFirst("div#user-modal-dp-wrapper")
    val avatarUrl = userInfo?.selectFirst("img")?.absUrl("src")
    val username = userInfo?.selectFirst("#user-modal-name")?.text()
    val userHref = body.selectFirst("#user-modal-trigger")?.attr("href")
    val userId = USER_ID_REGEX.find(userHref.orEmpty())?.groupValues?.getOrNull(1)
    // ...
    return HomePage(
        csrfToken = csrfToken,
        avatarUrl = avatarUrl,
        username = username,
        banner = banner,
        sections = sections,
        userId = userId,  // 关键：userId 为 null 表示未登录
    )
}
```

**登录态判断**:
- **WebLoginFeature.kt:117-129** - `verifyCurrentSession()`
```kotlin
private suspend fun verifyCurrentSession(): AuthSnapshot {
    val homePage = homeRepository.getHomePage()
    val isLoggedIn = !homePage.userId.isNullOrBlank()  // 判断逻辑
    return AuthSnapshot(
        isLoggedIn = isLoggedIn,
        message = if (isLoggedIn) "Login session verified" else "Login session expired",
        username = homePage.username,
    )
}
```

**异常映射**:
- **MutationGuards.kt:9-21** - 前置 guard
```kotlin
internal fun requireMutationCsrfToken(csrfToken: String?): String {
    return csrfToken?.takeIf { it.isNotBlank() }
        ?: throw DomainException(DomainError.Auth("Login session expired. Please sign in again."))
}

internal fun requireMutationUserId(userId: String?): String {
    return userId?.takeIf { it.isNotBlank() }
        ?: throw DomainException(DomainError.Auth("Login is required for this action."))
}
```

### iOS 当前实现
**VideoDetailViewModel 登录态检查**:
- **VideoDetailViewModel.swift:139-151** (toggleFavorite)
```swift
func toggleFavorite(snapshot: VideoDetailScreenSnapshot) {
    runAction(id: "favorite") {
        let nextValue = !snapshot.isFav
        try await self.videoFeature.setFavorite(
            videoCode: snapshot.videoCode,
            currentUserId: snapshot.currentUserId,  // 直接使用 snapshot 中的 userId
            csrfToken: snapshot.csrfToken,
            isFavorite: nextValue
        )
        // ...
    }
}
```

- **VideoDetailViewModel.swift:154-167** (toggleWatchLater)
- **VideoDetailViewModel.swift:169-181** (setMyListItem)

**snapshot 中的 userId 来源**:
- **VideoDetailScreenSnapshot.kt:372-387** - 从 `VideoDetailSnapshot` 转换
```swift
init(_ snapshot: VideoDetailSnapshot) {
    // ...
    currentUserId = snapshot.currentUserId  // 来自 KMP 层
    // ...
}
```

**KMP 层登录标志**:
- **LoginSessionMarker.kt:5-25** - 应用级登录标记
```kotlin
internal object LoginSessionMarker {
    private const val cookieName = "han1me_ios_web_login_confirmed"
    private const val appCookieDomain = "han1meviewer.local"
    
    fun List<SessionCookie>.hasConfirmedLogin(): Boolean {
        return any { cookie ->
            cookie.name == cookieName &&
            cookie.value == "true" &&
            cookie.domain == appCookieDomain
        }
    }
}
```

- **WebLoginFeature.kt:77-83** - `currentSessionSnapshot()`
```kotlin
suspend fun currentSessionSnapshot(): AuthSnapshot {
    if (!sessionStore.loadCookies().hasLoginSession()) {
        return AuthSnapshot(isLoggedIn = false, ...)
    }
    // ...
}
```

### 修复时需要触碰的函数/字段
- KMP: `KsoupHtmlParser.parseHome()` - 第 35-78 行，userId 提取逻辑
- KMP: `HomePage` 数据类 - userId 字段
- KMP: `WebLoginFeature.verifyCurrentSession()` - 第 117-129 行，登录态判断
- KMP: `MutationGuards.kt` - requireMutationUserId/requireMutationCsrfToken
- iOS: `VideoDetailViewModel.toggleFavorite/toggleWatchLater/setMyListItem()` - 第 139-181 行
- iOS: `VideoDetailScreenSnapshot.currentUserId` - 第 361 行

---

## 5. 未登录前置 guard

### Android 实现细节
**登录态检查**:
- **MutationGuards.kt:18-21**
```kotlin
internal fun requireMutationUserId(userId: String?): String {
    return userId?.takeIf { it.isNotBlank() }
        ?: throw DomainException(DomainError.Auth("Login is required for this action."))
}
```

**Mutation 调用链**:
- **KtorVideoRepository.kt:36-61** (setFavorite)
```kotlin
override suspend fun setFavorite(...) {
    val token = requireMutationCsrfToken(csrfToken)  // 抛异常
    val currentUserId = requireMutationUserId(userId)  // 抛异常
    // ... 构建请求
}
```

**异常映射到 UI**:
- 异常类型: `DomainException(DomainError.Auth(...))`
- UI 层通过 `catch` 块捕获，显示 toast 或错误提示

### iOS 当前实现
**登录态检查**:
- **VideoDetailViewModel.swift:139-151** (toggleFavorite)
```swift
func toggleFavorite(snapshot: VideoDetailScreenSnapshot) {
    runAction(id: "favorite") {
        let nextValue = !snapshot.isFav
        try await self.videoFeature.setFavorite(
            videoCode: snapshot.videoCode,
            currentUserId: snapshot.currentUserId,  // 可能为 nil
            csrfToken: snapshot.csrfToken,  // 可能为 nil
            isFavorite: nextValue
        )
        // ...
    }
}
```

**错误处理**:
- **VideoDetailViewModel.swift:205-221** (runAction)
```swift
private func runAction(id: String, operation: @escaping () async throws -> Void) {
    guard !runningActionIDs.contains(id) else { return }
    runningActionIDs.insert(id)
    Task { [weak self] in
        defer { runningActionIDs.remove(id) }
        do {
            try await operation()
        } catch {
            CloudflareChallengeCenter.requestChallengeIfNeeded(for: error)
            actionMessage = VideoActionMessage(message: ErrorMessage.userFriendly(error))
        }
    }
}
```

**登录状态全局标志**:
- **LoginSessionMarker.kt:18-24** - `hasConfirmedLogin()` 检查
- **WebLoginFeature.kt:77-83** - `currentSessionSnapshot()` 返回 `AuthSnapshot.isLoggedIn`

### 修复时需要触碰的函数/字段
- KMP: `MutationGuards.kt` - requireMutationUserId/requireMutationCsrfToken
- KMP: `KtorVideoRepository.setFavorite/setMyListItem/setArtistSubscription()` - 第 36-112 行
- iOS: `VideoDetailViewModel.toggleFavorite/toggleWatchLater/setMyListItem()` - 第 139-181 行
- iOS: `VideoDetailViewModel.runAction()` - 第 205-221 行，错误处理
- iOS: `LoginSessionMarker.hasConfirmedLogin()` - 全局登录标志检查

---

## 6. SearchFilterSheet 重置逻辑

### Android 实现细节
**重置按钮行为**:
- **SearchFilterSheet.swift:58-62** (iOS 实现，但反映 Android 预期)
```swift
ToolbarItem(placement: .navigationBarLeading) {
    Button("重置") {
        draft.reset()
        onReset()  // 调用回调
    }
}
```

**onReset 回调**:
- **SearchView.swift:67-70**
```swift
onReset: {
    viewModel.resetFilters()
    viewModel.search(keyword: keyword, filters: SearchFilterState())
}
```

**重置逻辑**:
1. 重置 UI 状态 (`draft.reset()`)
2. 调用 `onReset()` 回调
3. 回调中同时重置 ViewModel 和触发新搜索

### iOS 当前实现
**SearchFilterSheet 重置**:
- **SearchFilterSheet.swift:58-62**
```swift
Button("重置") {
    draft.reset()
    onReset()
}
```

**SearchView 中的 onReset**:
- **SearchView.swift:67-70**
```swift
onReset: {
    viewModel.resetFilters()
    viewModel.search(keyword: keyword, filters: SearchFilterState())
}
```

**SearchFilterState.reset()**:
- 需要查看 KMP 层的 `SearchFilterState` 定义

**问题**: 重置后立即触发搜索，UI 和数据同时更新。

### 修复时需要触碰的函数/字段
- iOS: `SearchFilterSheet.swift:58-62` - 重置按钮逻辑
- iOS: `SearchView.swift:67-70` - onReset 回调
- iOS: `SearchViewModel.resetFilters()` - 需要查看实现
- KMP: `SearchFilterState.reset()` - 重置方法
- KMP: `SearchViewModel` 的 filter 管理逻辑

---

## 总结

| 修复点 | 关键文件 | 核心函数/字段 | 修复方向 |
|------|--------|------------|--------|
| 1. 错误响应保存 cookie | KtorCookieBridge.kt, Han1meHttpClient.kt | saveResponseCookies(), HttpResponseValidator | 在 validator 前保存 cookie |
| 2. WebView UA 统一 | HanimeNetworkDefaults.kt, LoginView.swift, CloudflareChallengeView.swift | DEFAULT_USER_AGENT, makeUIView() | 设置 WKWebView.customUserAgent |
| 3. CF cookie 元数据 | CloudflareFeature.kt, LoginView.swift | importChallengeCookieHeader(), encodeCookiesForImport() | 保留完整 cookie 元数据 |
| 4. parseHome 登录态 | KsoupHtmlParser.kt, WebLoginFeature.kt | parseHome(), verifyCurrentSession() | userId 为 null 表示未登录 |
| 5. 未登录前置 guard | MutationGuards.kt, VideoDetailViewModel.swift | requireMutationUserId(), toggleFavorite() | 抛异常或提前检查 |
| 6. SearchFilterSheet 重置 | SearchFilterSheet.swift, SearchView.swift | onReset(), resetFilters() | 重置 UI 和触发搜索 |

