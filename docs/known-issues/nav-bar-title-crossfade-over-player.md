# Known Issue: Navigation title cross-fades on top of the video player during the swipe-back transition

Status: **Mitigated** (option 3 applied). Proper fix deferred to a future UIKit
navigation refactor (option 2).

## Symptom

When the user performs an interactive (edge-swipe) pop from `VideoDetailView`
back to `HomeView`, the destination page's large navigation title ("首页")
**occasionally** appears composited *on top of* the video player view for a
fraction of the transition, instead of sliding in cleanly underneath the page
content.

It is intermittent: whether it is visible depends on swipe speed, how far the
swipe travels, and whether the gesture completes or is cancelled (rubber-bands
back).

## Root cause

A single `NavigationStack` (`UINavigationController` underneath) owns exactly
**one** navigation bar, and that bar is always the top-most subview of the
container — it is composited above every page's content.

- `HomeView` uses `.navigationTitle("首页")`, which defaults to the **large**
  title display mode. The large-title area is tall and, in the collapsed/large
  cross-fade, can extend down over the region where a pushed page's content
  sits.
- `VideoDetailView` hides the bar entirely with
  `.toolbar(.hidden, for: .navigationBar)` and lets the player draw its own
  floating back button, so the player content runs all the way to the top of
  the screen.

During an interactive pop, UIKit prepares the about-to-be-revealed `HomeView`
by **fading its navigation bar from alpha 0 → 1** and populating it with the
"首页" title. But at that moment `VideoDetailView` (with the full-bleed player)
has not yet slid away. Because the shared nav bar is the top-most layer, the
fading-in bar — carrying "首页" — is composited **above** the player.

This is fundamentally a *bar visibility mismatch* between adjacent pages
(hidden on the detail page, shown on the home page). The mismatch is animated
as an asymmetric cross-fade rather than the normal horizontal title slide, and
the cross-fade's timing is not driven by the interactive gesture's progress —
hence the "sometimes" and the "during rubber-band" behaviour.

## Why SwiftUI makes this hard to fix correctly

The clean fix is the UIKit one: implement
`navigationController(_:willShow:animated:)` and, inside it, drive
`setNavigationBarHidden(_:animated:)` **alongside the transition coordinator**
(`transitionCoordinator?.animate(alongsideTransition:)`), so the bar's
appearance/disappearance is perfectly synchronised with the push/pop — including
correctly reversing when an interactive pop is cancelled.

In the current SwiftUI-first architecture we do not own the
`UINavigationController` transition lifecycle. We only reach it indirectly via
the `InteractivePopEnabler` representable (which re-enables the edge-swipe
recogniser after `.toolbar(.hidden)` disables it). Hooking the navigation
controller delegate to take over bar-hidden animation from SwiftUI is fragile:
SwiftUI continually re-asserts its own bar state from the `.toolbar` modifiers,
so our delegate and SwiftUI fight over the same bar, producing flicker of a
different kind. This is one concrete, reproducible reason the navigation layer
is a candidate for a future **UIKit-based navigation container** refactor
(tracked as "option 2").

## Options considered

1. **Force `HomeView` to `.inline` title.** One line, zero risk, reduces but
   does not guarantee elimination — an inline bar is short so it rarely reaches
   the player, but the cross-fade-over-player can still occur.
2. **UIKit nav-controller delegate + transition coordinator.** The correct,
   system-accurate fix. Deferred: it requires owning the navigation transition
   lifecycle, which the current SwiftUI navigation stack does not expose
   cleanly, and it fights SwiftUI's own `.toolbar` bar management. **This is a
   motivating reason for a future UIKit navigation refactor.**
3. **Make both pages consistent: hide the system bar on `HomeView` too and
   self-draw the "首页" title inside Home's own content.** *(Applied.)* With no
   "首页" element living in the shared navigation bar, there is nothing for the
   transition to fade on top of the player; the self-drawn title is part of
   Home's view hierarchy, so it slides in with Home and is clipped to Home's
   bounds. We replicate the large→inline collapse-on-scroll feel manually so the
   page still matches the other tabs visually.

## Current mitigation (option 3)

`HomeView`:
- Adds `.toolbar(.hidden, for: .navigationBar)` so the shared bar carries no
  title for this page.
- Draws "首页" as a large title at the top of its own scroll content, and
  shrinks/fades it toward an inline-style compact header as the user scrolls,
  reproducing the standard large-title collapse used on the other tab roots.

Trade-off: we lose the *system* large-title behaviour (automatic accessibility
sizing, the system's exact collapse curve). The manual version is a close visual
match but is not the real thing — another data point in favour of the eventual
UIKit refactor.

## Follow-up

When the navigation layer is migrated to a UIKit-hosted container, implement
option 2 and delete the self-drawn title workaround in `HomeView`, restoring a
real system large title with correctly synchronised bar transitions.
