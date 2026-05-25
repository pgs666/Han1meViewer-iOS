# Comment Feature SwiftUI Port

Time: 2026-05-25 15:48:32 +08:00

## User Input

Original:

```text
完整移植评论区功能，使用swiftui
```

English translation:

```text
Fully port the comment section feature using SwiftUI.
```

Additional note:

```text
以后你有需要安装的包就告诉我，我来安装
```

English translation:

```text
In the future, tell me when you need packages installed, and I will install them.
```

CI note:

```text
编译测试需要推送到GitHub，然后用gh watch --exit-status就行
```

English translation:

```text
Compile testing needs to be pushed to GitHub, then use gh watch --exit-status.
```

## Changes

- Added shared KMP comment models for comment threads, comment rows, like metadata, target type, comment place, and report reasons.
- Added `CommentRepository` and `KtorCommentRepository` for:
  - loading video comments,
  - loading child replies,
  - posting top-level comments,
  - posting replies,
  - liking/disliking comments,
  - reporting comments.
- Added comment parsing to `KsoupHtmlParser` for `loadComment` and `loadReplies` JSON payloads.
- Added parser tests for top-level comments and child replies.
- Added `CommentFeature` as the Swift-facing shared business API.
- Exposed `commentFeature()` from `SharedAppEnvironment`.
- Replaced the video detail comment placeholder with SwiftUI `CommentView`.
- Added `CommentViewModel` and SwiftUI UI for:
  - loading comments,
  - sorting comments,
  - posting comments,
  - replying,
  - loading child replies,
  - liking/disliking,
  - reporting.
- Threaded `CommentFeature` through every `VideoDetailView` navigation entry.
- Aligned iOS report reasons with Android `report_reason.json` reason keys.
- Replaced the report confirmation dialog with an iOS 15-compatible `isPresented` binding form.
- Removed stale localization keys for the old comment placeholder.
- Fixed child-reply sheet interactions so likes/dislikes update the visible reply sheet state.
- Moved child-reply report handling into the reply sheet instead of routing through the parent sheet.
- Added `CommentFeatureTest` coverage for loading comments, liking parent comments, disliking child replies, posting replies, reporting, and Android-aligned report reasons.

## Why

- The video detail page already had a comment tab, but it was only a placeholder.
- Android already has the complete comment workflow, so this ports the same functional surface into the iOS SwiftUI path.

## Verification

- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:jvmTest` passed.
- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64 ./gradlew :shared:compileKotlinMetadata` passed.
- `python3 -m json.tool iosApp/Localizable.xcstrings` passed.
- `git diff --check` passed.
- Static search confirmed the old `AndroidStyleCommentsPlaceholder` implementation is gone.
- Static search confirmed the old placeholder strings are gone from app sources and localization.
- Static search confirmed all current `VideoDetailView` calls pass `commentFeature`.

## Failed Attempt

- The first `./gradlew :shared:jvmTest` attempt could not run because this environment had no Java installed:

```text
ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
```

- After JDK 25 was installed, Gradle dependency resolution failed with Maven TLS handshake errors.
- The user installed JDK 21, and verification passed when running Gradle with `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64`.

## Follow-up

- Run the iOS/macOS build, because this Linux aarch64 environment cannot compile the Kotlin/Native iOS framework or Swift app locally.
