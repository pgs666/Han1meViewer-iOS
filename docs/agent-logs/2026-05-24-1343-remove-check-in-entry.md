# Remove Check-In Entry

## User Input

Original:

```text
删除签到这个功能，不需要做它
```

English translation:

```text
Remove the check-in feature; it does not need to be implemented.
```

## What Changed

- Removed the "每日签到" placeholder row from the Mine tab.
- Updated the standing agent rules to state that the Android daily check-in/check-in feature must not be ported or reintroduced in the iOS app.

## Why

The user explicitly removed check-in from the iOS migration scope. Keeping even a placeholder entry would imply the feature is planned.

## Mistakes Or Failed Attempts

- None.

## Verification

- Pending local KMP test and GitHub Actions iOS build.

## Known Limits

- Historical agent logs still mention earlier check-in placeholders because those files are immutable work history and should not be rewritten.
