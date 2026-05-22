# Agent Log: Session Environment And Login Wiring

Time: 2026-05-22 13:10 +08:00

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## User Input

Original:

```text
我的action马上要限额了，麻烦直接改成公开仓库得了，然后进行下一步修改，这是我希望的修改： 1. Repository 模式不一致。 HomeFeature 自己创建 HttpClient，直接调用 KsoupHtmlParser，绕过了你声明的 HomeRepository 接口。VideoFeature 包装了 KtorVideoRepository，但 HomeFeature 没有。等你需要在首页请求中注入登录 Cookie（个性化内容）时，这种不一致会反噬。选一个模式统一执行。 2. Session 持久化建了但没接上。 KMP 侧有 SqlDelightSessionStore、CookieHeaderProvider、SetCookieParser，KtorAuthRepository 也在用它们。但 Swift 侧从未实例化数据库驱动，HomeFeature/VideoFeature 也没有注入 Cookie。意味着登录在 JVM 测试里能跑，但在实际 iOS app 里毫无效果。 1. 把 Session 持久化接入 Swift —— 实例化 DatabaseDriverFactory，把带 Cookie 的 Ktor 客户端传入 Feature。这解锁登录功能。 3. 把 LoginView 接上 KtorAuthRepository —— KMP 代码已经写好，只差连接。4. 实现 KtorSearchRepository + SearchFeature —— 沿用 Video 的同样模式。 5. 修复 Swift 侧错误处理 —— 把 DomainError 子类型映射成用户友好的提示。6. 实现分组首页 —— 用你已经解析的 HomeSection 数据。7. 替换 AsyncImage 为带缓存的图片库 —— Nuke 或 Kingfisher。
```

English translation:

```text
My GitHub Actions quota is about to run out, please just make the repository public, then proceed with the next modifications. These are the changes I want: 1. The Repository pattern is inconsistent. HomeFeature creates HttpClient itself and calls KsoupHtmlParser directly, bypassing the HomeRepository interface. VideoFeature wraps KtorVideoRepository, but HomeFeature does not. Once Home requests need login Cookie injection for personalized content, this inconsistency will bite back. Choose one pattern and apply it consistently. 2. Session persistence was created but is not wired. KMP has SqlDelightSessionStore, CookieHeaderProvider, SetCookieParser, and KtorAuthRepository uses them. But Swift never instantiates the database driver, and HomeFeature/VideoFeature do not inject Cookie. This means login can run in JVM tests but has no effect in the real iOS app. 1. Wire Session persistence into Swift: instantiate DatabaseDriverFactory and pass Cookie-enabled Ktor clients/features. This unlocks login. 3. Connect LoginView to KtorAuthRepository. The KMP code is already written; it only needs wiring. 4. Implement KtorSearchRepository + SearchFeature using the same pattern as Video. 5. Fix Swift error handling by mapping DomainError subtypes to user-friendly messages. 6. Implement grouped Home using the HomeSection data already parsed. 7. Replace AsyncImage with a cached image library such as Nuke or Kingfisher.
```

## What I Changed

- Changed the GitHub repository visibility to public using `gh repo edit`.
- Added a shared `SharedAppEnvironment` that creates `DatabaseDriverFactory`, `Han1meDatabase`, and `SqlDelightSessionStore` once.
- Added `AuthFeature` as a Swift-friendly wrapper around `AuthRepository`.
- Added `KtorCookieBridge` so Ktor repositories consistently inject stored Cookie headers and persist response cookies.
- Added `KtorHomeRepository` and changed `HomeFeature` to use `HomeRepository` instead of creating its own Ktor client/parser.
- Changed `KtorVideoRepository` to use the shared session store and Cookie bridge.
- Changed `VideoFeature` to receive a `VideoRepository`, matching the repository pattern.
- Updated the Swift app root to create one `SharedAppEnvironment` and pass it into Home, Video, and Login flows.
- Added `LoginViewModel` and wired `LoginView` to the real shared `AuthFeature`.
- Added `ErrorMessage.userFriendly(_:)` for basic user-facing network, timeout, and block/Cloudflare messages.
- Added a simple `TabView` so Login is reachable from the running app.

## Why

The app could already browse Home, open details, and play a parsed source, but login state could not affect those requests. The important next step is a single shared session path used by Auth, Home, and Video.

## Mistakes Or Failures

- None yet in this edit. CI may still reveal Kotlin/Swift export naming issues because this touches the framework boundary.

## Verification

Pending:

```powershell
.\gradlew.bat :shared:jvmTest
.\gradlew.bat :shared:compileTestKotlinIosSimulatorArm64
```

Then push for GitHub Actions iOS app build and unsigned IPA verification.

## Known Limits

- Search, grouped Home sections, and cached image loading are not included in this slice yet.
- Login success still depends on the live site behavior and Cloudflare state.
- Error mapping is currently heuristic because shared exceptions are not yet normalized into a Swift-friendly `DomainError` result type.
