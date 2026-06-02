# Agent Log: Root Comment Composer

## User Input

Original:

```text
评论框为什么不能在整个view的最上层呢，就像首页的tab栏一样
还有点击查看x条回复的时候，回复别人的时候，这个输入框都要隐藏
```

English translation:

```text
Why can't the comment box be at the top layer of the whole view, like the home tab bar?
Also, when tapping to view x replies or replying to someone, this input box should be hidden.
```

## What Changed

- Promoted the main comment composer to a root-level `VideoDetailView` overlay, above the player/detail/pager content stack.
- Scoped safe-area ignoring to the content layer, so the detail scroll area can still reach the screen bottom while the composer remains anchored as page chrome.
- Moved horizontal pager exclusion-frame collection to the root layer so touches on the composer do not start horizontal paging.
- Added a `CommentView` callback for internal comment overlays.
- Hid the root composer while reply sheets or reply-thread sheets are active.

## Why

The composer is page chrome, not comments-list content. Keeping it at the root layer avoids clipping and frame constraints from the pager and scroll views, matching the way a tab bar floats above page content.

Reply and reply-thread flows have their own input context. Showing the root-level main comment composer under those flows is visually confusing and can compete with the sheet's focused input.

## Verification

- `git diff --check` passed.
- `./gradlew :shared:jvmTest` passed on local Linux aarch64. Kotlin/Native remains unsupported on this host, so the iOS Swift build is verified through GitHub Actions.
