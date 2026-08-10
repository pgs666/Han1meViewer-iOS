# Three-Column iPhone Hanime Grid

## User Input

Original:

```text
我希望iPhone上的里番页也是三列的，iPad上倒是可以不变
```

English translation:

```text
I also want the hanime page on iPhone to use three columns. The iPad layout can remain unchanged.
```

## What Changed

- The home `ecchiAnime` section's “more” page now uses a fixed three-column grid when running on iPhone.
- iPad continues using the existing adaptive grid with a 160-point minimum card width.
- Normal landscape-cover categories keep the existing adaptive grid on every device.

## Why

The page already selected the correct `268:394` portrait card shape, but it shared the landscape grid's adaptive 160-point minimum width, which normally produced only two columns on iPhone.

## Verification

- Confirmed the condition is limited to `.hanimePortrait` cards on `.phone` devices.
- Confirmed the iPad and non-hanime branches still return the original adaptive grid definition.
- Final iOS compilation is performed by GitHub Actions after push.
