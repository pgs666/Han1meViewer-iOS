# Search Filter Badge Position

## User Request

中文原文：

> 依然有问题

English translation:

> There is still a problem.

## Context

- The attached screenshot shows the search filter button badge still visually attached to the circular filter button instead of sitting cleanly above its top-right edge.
- The previous implementation placed the badge in an outer `ZStack` around the toolbar button, but the iOS 26 toolbar button renders as a larger system control than the SF Symbol itself.

## Changes

- Moved the badge overlay into the button label and anchored it to a fixed 44x44 button content area.
- Removed extra outer top/trailing padding that pushed the badge alignment away from the actual button frame.

## Verification

- Pending local checks and CI build.
