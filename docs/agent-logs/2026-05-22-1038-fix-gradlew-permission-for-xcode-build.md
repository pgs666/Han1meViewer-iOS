# Agent Log: Fix Gradle Wrapper Permission For Xcode Build

Time: 2026-05-22 10:38 +08:00

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## What Went Wrong

The first `iOS App Build` workflow failed in the Xcode pre-build script.

GitHub Actions run:

- `26264407478`

Error:

```text
./gradlew: Permission denied
Command PhaseScriptExecution failed with a nonzero exit code
```

Cause:

- The repository was created and edited on Windows.
- The `gradlew` executable bit was not available to the macOS Xcode build phase.

## What I Changed

1. Updated `project.yml` pre-build script:

```sh
chmod +x ./gradlew
./gradlew :shared:embedAndSignAppleFrameworkForXcode
```

2. I will also mark `gradlew` executable in Git metadata with:

```sh
git update-index --chmod=+x gradlew
```

## Expected Result

The next `iOS App Build` run should get past the Gradle wrapper permission error and proceed to the real KMP framework embed/link step.
