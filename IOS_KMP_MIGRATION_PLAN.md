# Han1meViewer iOS Migration Plan: KMP Shared Business Layer + Native SwiftUI

## Summary

- Target: an independent iOS repository.
- First release scope: playback MVP with login, home, search, video detail, and online playback.
- Android remains the source of truth.
- Extract shareable business code from `logic/model`, `Parser`, and `NetworkRepo`.
- Do not migrate Android UI, downloads, widgets, WorkManager, Media3, Jiaozi, or mpv for MVP.
- Fixed stack: KMP shared module, Ktor Client, kotlinx.serialization, KMP HTML parser, SQLDelight, SwiftUI, and AVPlayer.

## Key Changes

- Create an independent iOS repository structure:
  - `shared/` for KMP code.
  - `iosApp/` for the Xcode SwiftUI app.
- Expose a minimal Swift-facing shared API:
  - `AuthRepository.login(email, password): LoginResult`
  - `HomeRepository.getHomePage(): HomePage`
  - `SearchRepository.search(params, page): PageResult<List<HanimeInfo>>`
  - `VideoRepository.getVideo(videoCode): HanimeVideo`
  - `SessionStore` for login cookies, Cloudflare cookies, base URL, User-Agent, and proxy configuration placeholders.
- Migrate and de-platform Android code:
  - Move pure `logic/model` data models to `shared/commonMain`.
  - Remove `Parcelable`, Compose, Room, and Android annotations from shared models.
  - Split `Parser.kt` into `HtmlParser`.
  - Remove `R.string`, `Log`, `Preferences`, and `applicationContext` from parsing code.
  - Replace parser errors with shared `DomainError`.
  - Split `NetworkRepo.kt` into KMP repositories.
  - Replace Retrofit/OkHttp with Ktor while preserving existing request paths and form fields.
- Native iOS layer:
  - SwiftUI pages: `LoginView`, `HomeView`, `SearchView`, `VideoDetailView`, `PlayerView`.
  - Use AVPlayer for playback URLs parsed from `HanimeVideo`.
  - Support quality switching, pause/resume, landscape, and fullscreen playback.
  - Use Nuke for image loading in MVP because it gives better caching and list performance than bare `AsyncImage`.
- MVP local data:
  - SQLDelight tables: `watch_history`, `search_history`, `session_cookie`.
  - Do not migrate Android history databases; iOS starts with an empty database.
- Explicitly out of MVP:
  - Offline downloads, download groups, keyframe editing, check-in, widgets, Firebase, profile editing, comment posting, favorite/playlist write operations, Android CI update channel.

## Implementation Steps

### Phase 1: Independent Repository And KMP Foundation

- Create `shared` KMP framework.
- Target `iosArm64` and `iosSimulatorArm64`.
- Add Ktor, serialization, SQLDelight, and coroutines.
- Wrap suspend APIs for Swift async/await.
- Do not expose Flow to Swift in the first pass.

### Phase 2: Shared Models And Parsing

- Migrate `HomePage`, `HanimeInfo`, `HanimeVideo`, search params, loading results, and error types first.
- Prepare one HTML fixture each for home, search, and video detail.
- Make parser test output equivalent to the current Android `Parser`.

### Phase 3: Shared Network And Session

- Configure Ktor Client with User-Agent, cookie storage/injection, redirects, timeouts, and base error mapping.
- Reproduce the Android login flow:
  - Fetch login page and parse CSRF token.
  - Submit login form.
  - Verify login state with a second visit.

### Phase 4: SwiftUI MVP

- Swift ViewModels call shared repositories directly.
- Keep loading/error/content state in Swift.
- Implement home list, search pagination, detail view, and online AVPlayer playback.

### Phase 5: Stabilization

- Add crash logging, network error UI, login expiration handling, and Cloudflare block messaging.
- Before TestFlight, validate on simulator and device:
  - Logged out and logged in states.
  - Weak network.
  - Background/foreground.
  - Orientation changes.
  - Expired or invalid playback sources.

## Test Plan

- Shared unit tests:
  - Login page CSRF parsing.
  - Home module parsing.
  - Search result pagination, including empty results and no-more-data.
  - Video detail parsing, including title, cover, playback sources, quality, tags, and description.
  - Cookie persistence and request reinjection.
- iOS integration tests:
  - Cold start restores cookies.
  - Failed login shows error.
  - Successful login enters home.
  - Search, pagination, detail navigation, and playback start work.
  - Quality switching continues playback.
- Regression acceptance:
  - Android repository continues building without changes.
  - iOS App completes login-to-playback on simulator and device.
  - Parser fixture tests fail clearly when live HTML structure diverges.

## Assumptions

- The independent iOS repository will not be wired back into Android for MVP.
- After stabilization, shared code can be consumed by Android via Git submodule, Git subtree, private Maven, or Swift Package style distribution.
- Offline download is excluded from MVP because iOS background download behavior increases implementation and review risk.
- iOS database starts fresh and only guarantees migrations from iOS v1 onward.
- Cloudflare MVP behavior is detection plus user-facing manual handling guidance.
- If embedded WebView Cloudflare handling becomes required, it will be a separate post-MVP phase.
