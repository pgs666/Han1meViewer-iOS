# Stabilize Home Banner Layout

## User Input

Original:

```text
主要是首页那张大banner图，iPad上的方案是临时的解决方案，我希望它的布局稳定一些
```

English translation:

```text
I mainly mean the large banner image on the home page. The iPad approach was a temporary solution, and I want its layout to be more stable.
```

## What Changed

- Fixed the home hero banner container to `16:9` on both iPhone and iPad.
- Kept the current compact 440-point maximum width and leading alignment on regular-width iPad layouts.
- Removed the decoded-image aspect measurement state, callback, and size-class reset path.
- Removed the now-unused image-load size callback from `CachedRemoteImage`.

## Why

The current website home hero is served at `1024 × 576`, and sampled home thumbnails are consistently `640 × 360`; both are `16:9`. The previous iPad fallback started at `3.2:1` and changed to the decoded image ratio after loading, so the banner row changed height during display. A fixed ratio gives the placeholder and loaded image exactly the same geometry.

## Verification

- Inspected the live `https://hanime1.me/` home page in a browser and confirmed the hero image is `1024 × 576`.
- Confirmed loaded home thumbnails across multiple sections are `640 × 360` and their rendered containers use `16:9`.
- Confirmed no `onImageLoaded` or `measuredBannerAspect` references remain.
- Final Swift/iOS compilation is performed by GitHub Actions on macOS after push.

## Limits

- The iPad banner remains intentionally capped at 440 points wide; this change stabilizes its aspect and height rather than redesigning its overall placement.
- If the website changes the hero asset contract away from `16:9`, the fixed layout will crop it using the existing fill behavior.
