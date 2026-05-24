# Fix Following Parser Separator

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

- Planned fix: replace the copied Android artist/upload-time separator parsing with DOM-based subtitle link extraction.

## Why

The Android source displayed a corrupted separator string in this Windows shell, and copying it into KMP produced invalid Kotlin syntax. Reading the subtitle links directly is simpler and avoids depending on the broken separator text.

## Mistakes Or Failed Attempts

- `./gradlew :shared:jvmTest` failed at Kotlin compilation.
- An `apply_patch` attempt to replace the exact broken line failed because the corrupted string did not match reliably as patch context.

## Verification Planned

- Re-run `./gradlew :shared:jvmTest` after the fix.
- Continue to CI after local compilation passes.
