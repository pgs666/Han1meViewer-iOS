# Agent Plan: Switch To Vertical Slice

Time: 2026-05-22 10:28 +08:00

Repository: `C:\Users\PGS\Documents\Project\Han1meViewer-iOS`

Branch: `feature/ios-kmp-mvp`

## Reason For Adjustment

The architecture direction is accepted: KMP shared business layer plus native SwiftUI.

The execution order needs to move from horizontal shared-layer expansion to a vertical slice. The next risk to validate is not whether more models can compile; it is whether an iOS app can import and call the KMP framework, then render real shared data.

## What I Intend To Do Next

1. Add an Xcode project generation path with XcodeGen.
   - Keep the generated `.xcodeproj` out of source control.
   - Commit `project.yml` instead.
   - Let GitHub Actions generate the Xcode project on macOS.

2. Add a Swift-to-KMP smoke test.
   - Add a small KMP class that returns a simple string.
   - Import `Han1meShared` from Swift.
   - Display the KMP value in the SwiftUI app.

3. Add an iOS app CI workflow.
   - Install XcodeGen on `macos-15`.
   - Generate the Xcode project.
   - Build the SwiftUI app for an iOS simulator destination.
   - Use the KMP Gradle embed script from Xcode build phases.

4. Keep the existing KMP framework CI.
   - It still validates the shared framework directly.
   - The new workflow validates app-level integration.

## What I Will Not Do In This Step

- I will not add more parser coverage.
- I will not implement login yet.
- I will not implement AVPlayer yet.
- I will not write a full HomeRepository implementation until the iOS app can build and import KMP.

## Expected Outcome

After this step, GitHub Actions should prove that:

- `project.yml` can generate a valid Xcode project.
- SwiftUI app sources compile.
- The app target can link against `Han1meShared`.
- Swift can call a Kotlin class from the shared framework.

This becomes the base for the next vertical slice: real `HomeRepository.getHomePage()` through Ktor, parsed by `KsoupHtmlParser`, displayed in SwiftUI.
