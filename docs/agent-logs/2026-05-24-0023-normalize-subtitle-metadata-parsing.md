# Normalize Subtitle Metadata Parsing

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

- Planned fix: add one helper for extracting artist and upload-time metadata from subtitle links.

## Why

The existing parser tests use a single subtitle link containing both artist and date. Real pages may expose the metadata as multiple links. A helper can support both shapes without relying on corrupted separator text.

## Mistakes Or Failed Attempts

- After removing the broken separator split, `parsesNormalSearchCards` failed because the single-link fixture no longer split `Artist` from `2026-05-01`.

## Verification Planned

- Re-run `./gradlew :shared:jvmTest`.
- Continue to CI after local tests pass.
