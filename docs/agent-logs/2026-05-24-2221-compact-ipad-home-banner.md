# Compact iPad Home Banner

## User Input

Original:

```text
我希望iPad下的首页banner不要那么大
```

English translation:

```text
I want the home page banner to not be so large on iPad.
```

## Changes

- Added size-class aware banner sizing on the home page.
- iPhone keeps the existing full-width 16:9 banner behavior.
- iPad regular width now caps the banner at 760 points and uses a wider 2.35:1 aspect ratio so it is shorter and less dominant.
- Centered the capped banner within the home content area.

## Verification

- `./gradlew :shared:jvmTest` passed.
- `git diff --check` passed.
- No manual GitHub Actions run will be triggered.
