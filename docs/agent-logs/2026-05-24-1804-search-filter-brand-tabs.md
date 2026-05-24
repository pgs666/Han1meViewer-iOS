## User Input

Original:

```text
然后把筛选中的“品牌”变成可展开的样式，默认收起，再把筛选页的栏位样式改成横向的小tab
```

English translation:

```text
Then make the "Brand" filter expandable and collapsed by default, and change the filter page's section/category style into small horizontal tabs.
```

## What Changed

- Made the brand filter section expandable.
- The brand list is collapsed by default and expands when tapped.
- If brands were already selected when opening the filter sheet, the brand section starts expanded so selected state is visible.
- Changed the tag category selector from separate capsule buttons to a compact horizontal tab strip.

## Why

- The brand list is long and was taking too much vertical space in the filter sheet.
- The tag category selector should behave more like a compact tab control than a loose row of chips.

## Mistakes Or Failed Attempts

- The first draft used `.snappy`, which is not appropriate for an iOS 15 deployment target. I changed it to `.easeInOut(duration: 0.18)` before verification.

## Verification

- Pending local diff check and iOS CI build.

## Known Limits

- The brand list is still a large multi-select grid after expansion. A search field inside brands may be useful later.
