# Replace iOS App Icon

## User Input

Original:

```text
改成这个版本推一个ci
```

English translation:

```text
Switch to this version and push it to CI.
```

## What Changed

- Replaced every PNG in `AppIcon.appiconset` with the approved modern iOS-style mascot icon.
- Generated the existing 40, 58, 60, 80, 87, 120, 152, 167, 180, and 1024 pixel variants from the 1024-pixel candidate.
- Kept the existing Asset Catalog manifest and device-slot mappings unchanged.

## Why

The approved design preserves the cat-eared mascot and red H identity while removing the old baked-in white tile, black surround, and heavy bevel. Its larger subject and full-bleed background are more legible at iOS icon sizes.

## Verification

- Confirmed every generated file has the exact pixel dimensions required by `Contents.json`.
- Confirmed all variants are RGB PNG files without an alpha channel.
- Final Asset Catalog processing, Swift compilation, unsigned device build, and IPA packaging are verified by GitHub Actions on macOS.

## Limits

- This update supplies one universal appearance. It does not add separate iOS dark or tinted icon variants.
