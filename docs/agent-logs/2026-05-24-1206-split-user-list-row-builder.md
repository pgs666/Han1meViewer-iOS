## User Input

Original:

```text
继续完成下一步
```

English translation:

```text
Continue completing the next step.
```

## Changes

- Split `UserVideoListView` row rendering into separate read-only and removable helper views.
- Kept swipe-to-delete only on removable watch later and favorite lists.

## Why

GitHub Actions failed because Swift could not type-check the complex `@ViewBuilder` expression and reported a compiler diagnostic crash. Splitting the rows gives Swift simpler concrete view shapes.

## Mistakes Or Failed Attempts

- The previous implementation used an optional `onDelete` closure in the same row expression, which compiled on the Kotlin side but failed during Xcode build.

## Verification

- `./gradlew :shared:jvmTest` passed locally on Windows.
- Pending: GitHub Actions iOS build.

## Known Limits

- This only addresses the Swift build issue; runtime deletion still needs device verification against the website.
