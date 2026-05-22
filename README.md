# Han1meViewer iOS

Independent iOS migration workspace for the playback MVP.

## Scope

- KMP `shared` module for login, home, search, video detail, playback source parsing, session, and local MVP data.
- Native SwiftUI `iosApp` for the iOS user experience.
- Android remains the source of truth during the first migration pass.

## First Milestone

1. Build the KMP shared framework for `iosArm64` and `iosSimulatorArm64`.
2. Port pure models and parser fixtures from the Android repository.
3. Implement Ktor repositories and session persistence.
4. Wire SwiftUI screens to shared suspend APIs through Swift async/await wrappers.
