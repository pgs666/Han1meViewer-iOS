# Fix: nav-bar title cross-fading over the player during swipe-back (option 3)

## User Input

Original:

```text
把这个问题写成一个文件，放在doc里面，这是未来uikit重构的一个理由，我想选择2，但是现在版本不适合引入。先选择3，然后让标题滚动收缩效果和其他页面的收缩效果一样。
```

English translation:

```text
Write this problem up as a file under docs — it's a reason for the future
UIKit refactor. I want to choose option 2, but the current version isn't
suitable for introducing it. Go with option 3 for now, and make the title's
scroll-collapse effect match the collapse effect on the other pages.
```

## What changed

1. **docs/known-issues/nav-bar-title-crossfade-over-player.md** (new): documents
   the bug (the single shared navigation bar of a NavigationStack is composited
   above all page content; when popping back from `VideoDetailView` — which
   hides its bar and lets the full-bleed player run to the top — UIKit fades the
   revealed `HomeView` bar with its large "首页" title in from alpha 0, so the
   title momentarily renders on top of the player). Records the 3 options,
   selects option 3 as the mitigation, and explains why option 2 (UIKit
   `navigationController(_:willShow:animated:)` + `transitionCoordinator` driven
   `setNavigationBarHidden`) is the correct fix but is deferred — it requires
   owning the navigation transition lifecycle that the current SwiftUI stack
   doesn't expose cleanly, which is a concrete motivation for the future UIKit
   navigation refactor.

2. **iosApp/HomeView.swift** (option 3): hide the system nav bar on Home
   (`.toolbar(.hidden, for: .navigationBar)`) so the shared bar carries no
   title that could fade over the player. Draw "首页" as a large title at the
   top of Home's own scroll content and collapse it into a compact inline
   header on scroll, reproducing the system large→inline behaviour used by the
   other tab roots:
   - `@State scrollOffset` + computed `inlineTitleProgress` (`0…1` over the
     first 36pt of scroll).
   - A zero-height `GeometryReader` sentinel writes the offset into a new
     file-scope `HomeScrollOffsetPreferenceKey` using a uniquely-named
     coordinate space (`"homeScroll"`); read back via `.onPreferenceChange`.
   - Large `Text("首页")` at the top of the `LazyVStack` fades out
     (`opacity(1 - progress)`); a compact `Text("首页")` overlay pinned to the
     top with a `.bar` background fades in (`opacity(progress)`,
     `allowsHitTesting(false)`).

## Why this approach

Option 3 makes both adjacent pages consistent (neither shows a system bar
title), so there is nothing in the shared bar to cross-fade onto the player.
The title becomes part of Home's own view hierarchy and is therefore clipped to
Home and slides in with it. This is the minimal change that fully removes the
artifact without taking over the UIKit transition lifecycle.

## Mistakes / failed attempts

- First wrote `inlineTitleProgress` as `CGFloat`; `.opacity()` takes `Double`
  and Swift won't implicitly convert, so it's typed `Double` with an explicit
  `Double(scrollOffset)` conversion.

## Verification

- Verified file structure via document symbols (HomeView + new
  HomeScrollOffsetPreferenceKey parse correctly).
- Pushed to `main`; relies on GitHub Actions (`:shared:jvmTest` + xcodebuild
  iOS device build) for the authoritative build (no local Xcode available).

## Known limits / follow-up

- The self-drawn collapse is a close visual match, not the real system large
  title — it lacks the system's exact collapse curve and automatic
  accessibility text sizing. When the navigation layer moves to a UIKit-hosted
  container, implement option 2 and delete this workaround (see the known-issue
  doc).
- The inline header uses a fixed 36pt crossover; if Dynamic Type makes the
  large title much taller, the crossover point may want to scale with it.
