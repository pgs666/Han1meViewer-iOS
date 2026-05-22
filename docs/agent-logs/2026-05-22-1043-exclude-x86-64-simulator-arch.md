# Agent Log: Exclude x86_64 Simulator Architecture

Time: 2026-05-22 10:43 +08:00

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## What Went Wrong

After fixing `gradlew` permissions, the next `iOS App Build` progressed through the Gradle KMP embed step, but failed at Xcode linking.

GitHub Actions run:

- `26264469095`

Important error:

```text
ld: warning: ignoring file 'Han1meShared.framework/Han1meShared': fat file missing arch 'x86_64', file has 'arm64'
Undefined symbols for architecture x86_64:
  "_OBJC_CLASS_$_Han1meSharedSharedSmokeTest"
ld: symbol(s) not found for architecture x86_64
```

Cause:

- The GitHub macOS runner is Apple Silicon.
- KMP generated an `arm64` iOS simulator framework.
- Xcode's generic simulator build also attempted an `x86_64` link.

## What I Changed

Updated `project.yml` target build settings:

```yaml
EXCLUDED_ARCHS[sdk=iphonesimulator*]: x86_64
```

## Expected Result

The next app build should link only the `arm64` simulator slice and get past the missing `x86_64` framework issue.

## Future Note

If Intel simulator support is required later, add an `iosX64()` target and produce an XCFramework instead of relying on a single simulator framework.
