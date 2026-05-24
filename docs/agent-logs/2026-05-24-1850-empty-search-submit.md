## User Input

Original:

```text
现在空关键词依然不能触发搜索啊
```

English translation:

```text
Empty keywords still cannot trigger search now.
```

## What Changed

- Disabled automatic return-key gating on `UISearchTextField` so the system keyboard search key can be tapped when the keyword is empty.

## Why

- The KMP search pipeline already accepts an empty keyword.
- The issue was the system keyboard search key being disabled for empty text, not the search pipeline.

## Mistakes Or Failed Attempts

- I first added an extra keyboard toolbar search button.
- The user clarified that only the built-in keyboard search key should be fixed, so I removed the extra toolbar button before committing.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- Pending iOS CI verification.
