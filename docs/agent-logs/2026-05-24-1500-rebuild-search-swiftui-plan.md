# Agent Log: Rebuild Search With SwiftUI Filters

## User Input

Original:

```text
现在完整重做一遍搜索页面，要求是使用纯swiftUI，然后添加筛选面板（类似安卓版）
```

English translation:

```text
Now completely redo the search page. It must use pure SwiftUI, and add a filter panel similar to the Android version.
```

## Changes

- Rebuild the iOS search screen as a pure SwiftUI flow with a search field, prominent search action, filter entry, history, active filter summary, and result list.
- Add a SwiftUI filter sheet modeled after Android's advanced search sheet:
  - type
  - sort option
  - tags grouped by category
  - fuzzy tag matching
  - release date
  - video duration
- Port Android search option JSON files into the iOS app bundle so filter choices stay aligned with Android.
- Extend the KMP search feature so Swift can pass advanced search parameters through to Ktor.
- Added a Swift-side search option catalog and filter state model.
- Added KMP `SearchFeature.searchAdvanced(...)` and wired genre, broad search, tags, duration, release date, and sort through `KtorSearchRepository`.

## Why

The existing iOS search page only supports keyword search. Android already exposes advanced filters and the KMP repository has most of the parameter surface, so this is the next useful non-player feature migration slice.

## Verification

- `.\gradlew :shared:jvmTest` passed locally.
- iOS/Xcode verification is pending GitHub Actions.

## Known Limits

- Advanced search history is not planned for this pass. Normal keyword history remains.
- Brand filtering is supported by KMP but not exposed in the first iOS filter sheet, matching the current Android sheet's visible primary filters.
