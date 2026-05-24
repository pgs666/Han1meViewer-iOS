# Cache Tab Pages

## User Input

Original:

```text
现在每个界面在切换时都会被重载，希望不要每次切换都重载（换句话说就是每个页面都要做缓存），然后删除我的页的订阅按钮，只保留tab栏的关注即可
```

English translation:

```text
Right now every screen reloads when switching. I hope they will not reload every time they are switched to; in other words, every page should be cached. Also remove the subscription button from the Mine page and keep only the Following tab in the tab bar.
```

## What Changed

- Added first-load guards to Home, Mine, Search history, local Watch History, and Video Detail.
- Kept explicit refresh actions able to reload data when the user asks for it.
- Removed the "我的订阅" row from the Mine tab because Following already exists as its own bottom tab.

## Why

Tab switching should preserve the current page state instead of issuing network/database requests each time a tab appears again.

## Mistakes Or Failed Attempts

- None so far.

## Verification

- Pending local KMP tests and GitHub Actions iOS build.

## Known Limits

- Detail screens are cached per live SwiftUI view instance. Opening a new detail screen instance for the same video can still perform a fresh load.
- Local data clearing from Settings can make already-open cached local-list screens stale until they are manually refreshed or recreated.
