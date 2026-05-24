# Refine iPad Home Banner Flow

## User Input

Original:

```text
这是现在的iPad版
```

English translation:

```text
This is the current iPad version.
```

## Changes

- Adjusted the iPad home banner from a centered hero-style block into a smaller leading-aligned content banner.
- Reduced the iPad banner width cap from 560 points to 440 points.
- Reduced the iPad banner reserved height to 138 points.
- Added a little extra spacing below the iPad banner so the first category row does not crowd it.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only an existing line-ending warning for `iosApp/HomeView.swift`.
- Swift compilation still needs CI or Xcode verification.
