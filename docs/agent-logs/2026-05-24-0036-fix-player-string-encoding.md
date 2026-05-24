# Fix Player String Encoding

## User Input

Original:

```text
继续下一步
```

English translation:

```text
Continue to the next step.
```

## What Changed

- Replaced corrupted Swift Chinese string literals in `VideoDetailView` and `PlayerView` with Unicode escape sequences.
- Recreated `PlayerView.swift` with valid Swift string literals after the corrupted text left unterminated strings.

## Why

PowerShell displayed and rewrote some Chinese strings as mojibake. Using Unicode escapes keeps the source file ASCII while still rendering Chinese text at runtime.

## Mistakes Or Failed Attempts

- A direct patch against the corrupted `PlayerView.swift` strings failed because the damaged string text did not match reliably as patch context.

## Verification Planned

- Re-run `./gradlew :shared:jvmTest`.
- Push and wait for GitHub Actions `iOS App Build`.
