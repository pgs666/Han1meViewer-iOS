# Agent Log: Clear Nuke Memory Cache

## User Input

Original:

```text
然后在设置里面加清除缓存的功能（并在按钮里面统计当前缓存的大小），继续完成下一步
```

English translation:

```text
Then add a clear-cache function in Settings, including the current cache size in the button, and continue with the next step.
```

## Changes

- Updated `CacheStorage.clear()` to clear Nuke's in-memory image cache before removing URL cache and files under the app Caches directory.
- Added the `Nuke` product as an explicit app dependency because `CacheStorage` now imports the core Nuke module directly.

## Why

The Settings cache button already measured the Caches directory and removed disk cache files. Since app images are loaded through Nuke, clearing only disk files could leave already-decoded images in memory until the app releases them naturally. Clearing Nuke's shared memory cache makes the Settings action more immediate and complete.

## Verification

- Pending after this edit.

## Known Limits

- The displayed cache size is still the disk cache size. It does not include transient in-memory cache, because iOS does not expose a stable app-wide memory-cache byte total for this use case.
