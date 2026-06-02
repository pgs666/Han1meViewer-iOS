# Agent Log: Anchor Comment Composer Safe Area

## User Input

Original:

```text
能不能把评论框铆定在屏幕内部？现在还是会出屏幕外。另外现在安全区设计又出问题了，scrollview无论何时都与屏幕最下面有一层gap
```

English translation:

```text
Can you anchor the comment box inside the screen? It still goes outside the screen now. Also the safe-area design is broken again: the scroll view always has a gap above the bottom of the screen.
```

## What Changed

- Restored inline video-detail content to ignore only the container bottom safe area, not the keyboard safe area.
- Passed the outer geometry bottom safe-area inset into the floating comment composer.
- Added the bottom safe-area inset inside the composer chrome so the input field stays above the home indicator.
- Increased comments tab bottom content clearance by the same inset so the floating composer does not cover the last comments.

## Why

The previous change stopped ignoring the container bottom safe area in inline mode. That fixed keyboard avoidance but reintroduced the visible bottom gap under the pager/scroll area. The correct split is to ignore only `.container` bottom for the page, while keeping keyboard safe-area avoidance active. The floating composer then needs its own bottom inset so it remains inside the screen.

## Verification

- Superseded by the root-level composer change logged in `2026-06-02-1942-root-comment-composer.md`.
- Local checks and GitHub Actions CI are run after both changes together.
