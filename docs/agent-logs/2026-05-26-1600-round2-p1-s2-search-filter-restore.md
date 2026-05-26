# P1-S2 搜索历史恢复 filters

**日期**: 2026-05-26 16:00 +0800
**分支**: fix/review-bugs-performance-quality
**commit**: b506a63

## User Input

Original:
```
review-ios-vs-android-round2.md 看看这个md，然后一条一条修复好有价值的
```

English translation:
```
Read review-ios-vs-android-round2.md and fix all valuable items one by one
```

## 改动总结

### P1-S2: 搜索历史点击不恢复 filters
- **文件**: `SearchHistory.sq`, `SearchHistoryStore.kt`, `SearchFeature.kt`, `SearchViewModel.swift`, `SearchView.swift`
- **改动**:
  - `search_history` 表新增 `filter_data TEXT` 列存储 JSON
  - `SearchHistoryStore.record()` 新增 `filterData` 参数
  - `SearchHistoryEntrySnapshot` 携带 `filterData`
  - `SearchFilterCodable` 桥接结构体用于 JSON 编解码
  - `SearchViewModel.restoreFromHistory()` 从 JSON 恢复 `SearchFilterState`
  - 点击历史项调用 `restoreFromHistory` 而非仅恢复 keyword
- **参考**: Android `SearchViewModel.restoreSearchMap()`
- **注意**: 恢复的 filter option 只有 searchKey，displayName 在 UI 中会从 catalog 重新解析

## 验证

- 本地 JVM 测试: 通过
- CI: `26455068833` 通过
