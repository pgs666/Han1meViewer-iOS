# Agent Working Rules

Last updated: 2026-05-24 10:21:00 +08:00

This file summarizes the user's standing requirements for future agent work in this repository.

## Repository Direction

- The chosen architecture is accepted:
  - KMP shared business layer.
  - Native SwiftUI iOS UI.
  - Ktor for HTTP.
  - SQLDelight for local persistence.
  - Ksoup for shared HTML parsing.
- Continue with a vertical-slice execution style.
- Do not keep expanding shared code horizontally without proving app-level integration.

## Current Priority

The app is not finished yet, so compatibility with earlier temporary iOS migration code is not a priority. The primary goal is to gradually port features from Android and keep proving them through working vertical slices.

Work toward an end-to-end MVP path:

1. iOS app builds.
2. Swift imports and calls KMP.
3. Real `HomeRepository.getHomePage()` works through Ktor.
4. Swift ViewModel renders loading/error/content.
5. HomeView displays real parsed data.
6. Then continue to video detail and AVPlayer playback.
7. Login and persistent session should be implemented when needed by the vertical slice.

## Compatibility Stance

- Do not add complexity to preserve compatibility with unfinished prototype behavior.
- Prefer replacing temporary scaffolding when it blocks feature migration or creates confusing user behavior.
- Preserve user data compatibility only after the iOS app has a real released baseline.
- Keep iOS deployment target decisions separate from app-internal prototype compatibility.

## Logging Requirements

- Every project file modification must create a new Markdown log file.
- Logs go under:

```text
docs/agent-logs/
```

- Do not overwrite previous log files.
- Each log should explain:
  - What changed.
  - Why it changed.
  - Any mistake or failed attempt.
  - Any verification performed.
  - Known limits or follow-up work.

## User Input Translation Requirement

- When a log is tied to a user request, include a `User Input` section.
- The section must include:
  - The user's original input.
  - An English translation.

Example:

```markdown
## User Input

Original:

```text
用户原文
```

English translation:

```text
English translation here.
```
```

## CI And Verification

- Code or build-system changes should be verified before being considered done.
- Local Windows verification is useful for KMP compilation, but iOS app integration must be verified on GitHub Actions/macOS.
- For non-code changes, do not wait for unrelated CI to finish before continuing to the next task.
- For code integration changes that affect app build, wait for the relevant workflow and fix failures.

## Git Requirements

- Use the correct Git identity:

```text
pgs666 <74764545+pgs666@users.noreply.github.com>
```

- Avoid using the wrong noreply id:

```text
159934348+pgs666@users.noreply.github.com
```

That id belongs to `Jshin918` and causes GitHub attribution to appear under the wrong account.

## Communication Preference

- Be direct and pragmatic.
- If an approach is wrong, say so and correct it.
- Keep moving on non-blocking work.
- When changing direction, write down the reason in a log.
