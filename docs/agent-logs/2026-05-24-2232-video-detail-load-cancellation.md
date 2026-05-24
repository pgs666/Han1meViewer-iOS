# Add Video Detail Load Cancellation

## User Input

Original:

```text
之前提到的 Bug（未修复）

2. ViewModel 无任务取消 — 快速切换视频时前一个加载任务不会取消
```

English translation:

```text
Previously mentioned bugs that are not fixed yet:

2. The ViewModel has no task cancellation. When switching videos quickly, the previous load task is not cancelled.
```

## Changes

- Added a retained `Task` for video detail loading.
- Cancelled the previous video detail load before starting a new one.
- Prevented stale cancelled requests from writing loaded or failed state.
- Changed the loaded video marker so it is only set after a successful load.
- Allowed retrying the same video after a failed load.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed with only an existing line-ending warning for `iosApp/VideoDetailViewModel.swift`.
- Swift compilation still needs CI or Xcode verification because this Windows environment cannot build the iOS app locally.
