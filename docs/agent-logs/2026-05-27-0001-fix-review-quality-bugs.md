# 修复 review-fix-quality.md 指出的 3 个必须修复的 bug

## User Input

Original:
查看这个文件 (review-fix-quality.md)

English translation:
Look at this file (review-fix-quality.md)

## What Changed

### H2 — 分辨率排序反向
- `KsoupHtmlParser.kt`: `sortedByDescending` → `sortedBy`
- RESOLUTION_ORDER 映射 2160→0, 240→6，sortedBy 让 value 小的（2160P）排前面

### M5 — POST 请求也会重试
- `Han1meHttpClient.kt`: 添加 `request.method == HttpMethod.Get` 过滤
- 只对 GET 请求重试，防止 mutation 重复执行

### H6 — encodeCookiesForImport 重复 3 次
- `LoginView.swift`: 删除 WebLoginStatusBar 和 Coordinator 中的重复定义
- 只保留 LoginView 中的一份，通过 `LoginView.encodeCookiesForImport()` 调用

## Why Changed
- review-fix-quality.md 指出这 3 个是"必须立即修的 bug，修了才能发版"

## Verification
- CI 通过 (run 26438119299)

## Mistakes
- H2: 初始实现用 sortedByDescending 但映射值是低值=高画质，导致排序反向
- M5: 初始实现没有过滤 HTTP 方法，POST 也会重试
- H6: Python 字符串替换导致函数被复制到 3 个 struct 中

## Known Limits
- 无
