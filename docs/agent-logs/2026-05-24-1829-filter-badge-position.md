## User Input

Original:

```text
这个数字为什么显示在了按钮里面，按道理是在按钮上面吧

你理解错了，我指的是筛选按钮的数字
```

English translation:

```text
Why is this number displayed inside the button? It should be above the button, right?

You misunderstood. I mean the number on the filter button.
```

## What Changed

- Moved the search filter active-count badge out of the icon `ZStack` and into an overlay on the toolbar button.
- Offset the badge above the button edge so it reads as a notification badge instead of content inside the filter button.

## Why

- The iOS toolbar button background is larger than the symbol label, so placing the badge inside the label stack made it visually sit inside the liquid glass button.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI verification.
