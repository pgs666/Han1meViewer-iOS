# Agent Log: Remove KMP iOS Workflow

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

## User Input

Original:

```text
那个kmp ios build 的workflow还有必要吗，没必要就删了吧
```

English translation:

```text
Is that KMP iOS Build workflow still necessary? If it is not necessary, delete it.
```

## Changes

- Removed `.github/workflows/kmp-ios-build.yml`.

## Why

The `iOS App Build` workflow already builds and embeds the KMP framework through the Xcode pre-build script, then produces the unsigned IPA used for device testing. The separate KMP iOS workflow duplicated framework compilation and uploaded a framework artifact that is no longer part of the current testing path.

## Verification

- Pending push and GitHub Actions verification through the remaining `iOS App Build` workflow.

## Known Limits

- Existing in-progress workflow runs that started before this deletion may still finish on GitHub. Future pushes should only run the remaining app build workflow.
