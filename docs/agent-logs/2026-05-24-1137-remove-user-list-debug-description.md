## User Input

Original:

```text
这最顶上的是什么东西，没必要存在的话就删除掉吧
```

English translation:

```text
What is the thing at the very top? If it is unnecessary, please remove it.
```

## Changes

- Removed the accidental top debug-looking text from watch later and favorite video list screens.
- Renamed list-related KMP `description` fields to `listDescription`.
- Updated Swift to read `snapshot.listDescription` instead of `snapshot.description`.

## Why

The top text was not intended UI. The field name `description` collided with Swift/object debug description behavior, so the app displayed the whole KMP snapshot string instead of a real list description.

## Mistakes Or Failed Attempts

- The previous implementation used an exposed KMP field named `description`, which was a poor interop name for Swift.

## Verification

- `./gradlew :shared:jvmTest` passed locally on Windows.
- Confirmed there are no remaining `description` fields on user video list snapshot/page models.
- Pending: GitHub Actions iOS build.

## Known Limits

- Real list descriptions will still display if the website provides one.
