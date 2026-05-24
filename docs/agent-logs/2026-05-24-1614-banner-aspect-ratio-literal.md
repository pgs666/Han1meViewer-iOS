## User Input

Original:

```text
先做banner跳转，然后做cloudflare，可以删除掉当前的md文件了
```

English translation:

```text
Do the banner navigation first, then Cloudflare handling. The current Markdown file can be deleted.
```

## What Changed

- Adjusted the banner image aspect ratio literal from integer-style `16 / 9` to `16.0 / 9.0`.

## Why

- SwiftUI's `aspectRatio` expects a floating-point value. Using explicit floating-point literals avoids accidental integer inference or build ambiguity.

## Mistakes Or Failed Attempts

- The first banner UI edit used `16 / 9`. I corrected it before committing.

## Verification

- Pending GitHub Actions iOS build after this correction.

## Known Limits

- This is only a compile-safety cleanup for the banner UI.
