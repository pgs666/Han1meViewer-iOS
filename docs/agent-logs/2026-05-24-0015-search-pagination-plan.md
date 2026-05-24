# Search Pagination Plan

## User Input

Original:

```text
开始做吧
```

English translation:

```text
Start doing it.
```

## What I Plan To Change

- Continue with the next vertical feature slice by adding search pagination.
- Expose page metadata from the KMP `SearchFeature` snapshot.
- Update the Swift search view model to keep loaded results, current page, and whether more pages are available.
- Add a load-more footer in the SwiftUI search result list.

## Why

Search currently loads only page 1, even though the KMP repository already receives `PageResult.hasNext`. Passing that state through to Swift makes the existing real search feature usable beyond the first page without adding a new architecture path.

## Verification Planned

- Run `./gradlew :shared:jvmTest`.
- Build or run the iOS workflow after pushing if Swift/KMP integration changes compile locally far enough to justify CI.

## Known Limits

- This change will focus on keyword pagination only. Advanced search filters can be ported later from the Android app.
