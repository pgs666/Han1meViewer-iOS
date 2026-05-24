# Fix Normal Card Separator

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

- Planned fix: replace the existing normal-card artist/upload-time separator split with subtitle link extraction.

## Why

After fixing the following parser, local compilation exposed the same corrupted separator string in `toNormalHanimeInfo()`. Using the subtitle links directly avoids relying on damaged text and keeps home/search parsing consistent with the new following parser.

## Mistakes Or Failed Attempts

- `./gradlew :shared:jvmTest` failed again after the first separator fix, this time in the older normal card parser.

## Verification Planned

- Re-run `./gradlew :shared:jvmTest`.
- Continue to CI after local compilation passes.
