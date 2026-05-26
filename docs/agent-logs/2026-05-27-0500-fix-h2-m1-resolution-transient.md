# Fix H2 + M1: Dynamic resolution sorting + @Transient

Date: 2026-05-27 05:00 +08:00
Branch: fix/review-bugs-performance-quality
Commit: 06cc603

## User Input

Original:

```text
Han1meViewer-iOS-review/review-ios-vs-android-round2.md 看看这个md，然后一条一条修复好有价值的
```

English translation:

```text
Look at this md and fix the valuable items one by one.
```

## What Changed

### H2 — Resolution sorting
- `KsoupHtmlParser.kt`: Removed static `RESOLUTION_ORDER` map (2160→0, 1440→1, ..., 240→6, auto→MAX-1).
- Replaced with dynamic parsing: `source.label.removeSuffix("P").toIntOrNull()?.let { -it } ?: Int.MAX_VALUE`
- This automatically handles any resolution label (540P, 360P, etc.) without needing to update a static map.

### M1 — @Transient on capturedAtEpochMillis
- `HanimeModels.kt`: Added `@Transient` annotation to `capturedAtEpochMillis` field in `HomePage` data class.
- This excludes the field from serialization, preventing data class equality issues when caching homepage data.

## Why

- H2: The static `RESOLUTION_ORDER` map would return `Int.MAX_VALUE` for any resolution not in the map (e.g., 540P), causing incorrect sorting.
- M1: Without `@Transient`, two `HomePage` objects with identical content but different capture times would not be equal, breaking cache comparison.

## Verification

- Local JVM test: `:shared:jvmTest` — BUILD SUCCESSFUL
- CI run `26462101246` — success (re-run after transient network error on artifact upload)

## Known Limits / Follow-up

- None. These are straightforward fixes.
