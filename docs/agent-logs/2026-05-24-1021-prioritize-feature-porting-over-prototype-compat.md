# Agent Log: Prioritize Feature Porting Over Prototype Compatibility

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
目前应用还没有完成，所以不需要考虑旧东西的兼容性问题，现在的首要目标是把功能慢慢搬运过来，记住它
```

English translation:

```text
The app is not complete yet, so there is no need to consider compatibility with old things. The current top priority is to gradually port features over. Remember this.
```

## Changes

- Updated `docs/AGENT_WORKING_RULES.md`.
- Added a compatibility stance stating that unfinished prototype behavior does not need to be preserved.
- Clarified that the priority is gradual Android feature migration through working vertical slices.

## Why

Future work should not spend engineering effort preserving temporary iOS migration behavior when the app has not reached a released baseline. The focus should stay on moving real features across and validating them.

## Verification

- Documentation-only change. No build required.

## Known Limits

- This is a standing project rule, not a code change.
