# Settings Screen

## User Input

Original:

```text
继续完成下一步
```

English translation:

```text
Continue completing the next step.
```

## What Changed

- Replaced the Mine tab's placeholder Settings button with a real `SettingsView`.
- Added settings rows for app version, project repository, and the Hanime website.
- Added local data actions to clear search history and local watch history.
- Added KMP support for clearing all local watch history records.

## Why

The remaining Mine tab placeholders should be reduced while avoiding player, download, and check-in work. A small settings page gives the app a real destination for local data management without expanding risky scope.

## Mistakes Or Failed Attempts

- None so far.

## Verification

- Pending local KMP tests and GitHub Actions iOS build.

## Known Limits

- This settings page intentionally does not include download settings, check-in settings, or player settings.
- Clearing local watch history does not affect online account history on the website.
