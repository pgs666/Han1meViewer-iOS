# Verify And Fix Six iOS Bugs

## User Request

6 个确认 bug（排除了 4 个误报）：P0 AVPlayer 清晰度切换未暂停旧播放器；P1 登录 didCompleteLogin 永不重置；P1 排序模式 UI/数据不同步；P2 搜索历史无障碍标签乱码；P2 isCompact 语义反转；P2 Cloudflare Cookie 导入数据竞争。看看这些分析出来的 bug 是不是真实存在的，如果是，修复它们。

## English Translation

There are six confirmed bugs after excluding four false positives: P0 AVPlayer quality switching does not pause the old player; P1 login didCompleteLogin never resets; P1 sort mode UI/data are out of sync; P2 search history accessibility label is garbled; P2 isCompact semantics are reversed; P2 Cloudflare cookie import has a data race. Check whether these reported bugs really exist, and if they do, fix them.

## Planned Actions

- Verify each reported bug against the current iOS code.
- Fix confirmed issues only.
- Keep the changes scoped to `Han1meViewer-iOS`.

## Results

- Confirmed and fixed AVPlayer quality switching by pausing the previous player before replacing it.
- Confirmed and fixed `didCompleteLogin` by resetting it whenever the login page reloads.
- Checked online history sorting and found it already calls `changeSortMode()` and reloads data, so this item is not currently reproducible.
- Confirmed the search-history accessibility label was correct in UTF-8 source, but kept it explicitly readable.
- Confirmed `isCompact` was a misleading name and renamed it to `usesCompactBanner` without changing the intended iPad-small-banner behavior.
- Confirmed Cloudflare cookie import could enter multiple concurrent imports and moved the import guard earlier.
