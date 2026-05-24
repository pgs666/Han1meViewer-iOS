## User Input

Original:

```text
Han1meViewer-2026-05-24-190053.ips
```

English translation:

```text
Han1meViewer-2026-05-24-190053.ips
```

## Crash Analysis

- The crash happens on the main thread while UIKit applies `UIAppearance` to `UISearchTextField`.
- The failing stack includes `+[UIView _performSystemAppearanceModifications:]`, `_UIAppearance`, and `-[UISearchTextField _didMoveFromWindow:toWindow:]`.
- This points at the previous global `UISearchTextField.appearance().enablesReturnKeyAutomatically = false` change.

## What Changed

- Removed the global `UISearchTextField.appearance()` mutation.
- Added a tiny SwiftUI/UIKit bridge that finds the current `UISearchTextField` instance and sets `enablesReturnKeyAutomatically = false` directly.
- This supersedes the previous `2026-05-24-1850-empty-search-submit.md` implementation.

## Why

- The user only wants the built-in keyboard search key enabled for empty keywords.
- Instance-level mutation avoids the iOS 26 UIAppearance crash while keeping the system search UI unchanged.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI verification.
