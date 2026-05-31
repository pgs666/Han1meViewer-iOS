# Han1meViewer iOS

[简体中文](README.md) | **English**

> An iOS port built on Kotlin Multiplatform + SwiftUI

[![Stars](https://img.shields.io/github/stars/pgs666/Han1meViewer-iOS?style=flat&logo=github&color=yellow)](https://github.com/pgs666/Han1meViewer-iOS/stargazers)
[![Forks](https://img.shields.io/github/forks/pgs666/Han1meViewer-iOS?style=flat&logo=github&color=blue)](https://github.com/pgs666/Han1meViewer-iOS/network/members)
[![License](https://img.shields.io/github/license/pgs666/Han1meViewer-iOS?style=flat&color=green)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/pgs666/Han1meViewer-iOS?style=flat&logo=git)](https://github.com/pgs666/Han1meViewer-iOS/commits/main)
[![CI](https://img.shields.io/github/actions/workflow/status/pgs666/Han1meViewer-iOS/ios-app-build.yml?branch=main&style=flat&logo=github-actions&label=build)](https://github.com/pgs666/Han1meViewer-iOS/actions/workflows/ios-app-build.yml)

An iOS port of the [Han1meViewer](https://github.com/misaka10032w/Han1meViewer) Android fork. Tech stack: Kotlin Multiplatform (shared business logic, networking, parsing, database) + SwiftUI (native iOS UI) + KSPlayer (custom control layer). Feature parity with the Android upstream: browsing, search, comments, favorites / subscriptions, downloads, local playback, and more.

> Documentation (FEATURES / ARCHITECTURE / BUILDING / known issues) is currently maintained in Chinese; the links below point to those documents.

## 📜 Credits & Acknowledgements

| Project | Author | Notes |
|------|------|------|
| [YenalyLiew/Han1meViewer](https://github.com/YenalyLiew/Han1meViewer) | Yenaly Liew | Original Android project, licensed under Apache License 2.0 |
| [misaka10032w/Han1meViewer](https://github.com/misaka10032w/Han1meViewer) | misaka10032w | Android fork, the upstream of this project |
| **This project** | pgs666 | iOS port |

Special thanks:

- **[YenalyLiew](https://github.com/YenalyLiew)** — author of the original Han1meViewer, who established the project's base architecture, HTML parsing logic, and core feature design
- **[misaka10032w](https://github.com/misaka10032w)** — maintainer of the Android fork, who added many features on top of the original (comment system, download management, HKeyframe, check-in system, privacy protection, etc.); this project's business logic and parsing rules mainly follow this version
- **The Kotlin Multiplatform ecosystem** — excellent KMP libraries such as [Ktor](https://ktor.io/), [SQLDelight](https://cashapp.github.io/sqldelight/), and [Ksoup](https://github.com/fleeksoft/ksoup)
- **iOS dependencies** — [KSPlayer](https://github.com/kingslay/KSPlayer) (video playback, GPL-3.0) and [Nuke](https://github.com/kean/Nuke) (image loading)

## 📚 Documentation

- [✨ Feature list](docs/FEATURES.md) — full feature inventory
- [🏗️ Architecture](docs/ARCHITECTURE.md) — tech stack, architecture diagram, directory structure
- [🛠️ Building from source](docs/BUILDING.md) — dev environment, setup, CI
- [⚠️ Known issues](docs/known-issues/README.md)

## 🗺️ Roadmap

Planned ports relative to the Android upstream (features not yet implemented):

- [ ] Manual / QR-code cookie import
- [ ] Playlist write operations (create / rename / delete, add / remove videos)
- [ ] User account page (profile details)
- [ ] Monthly preview (monthly release calendar)

> Daily check-in, HKeyframe, etc. are intentionally excluded (see ROADMAP for reasons). Full roadmap: [docs/ROADMAP.md](docs/ROADMAP.md).

## 📲 Installation

This project is not distributed through the App Store; installing it on a non-development iOS device requires **self-signing**.

Get the unsigned IPA:

- **Stable release**: download the latest `Han1meViewer-X.Y.Z-unsigned.ipa` from the [Releases](https://github.com/pgs666/Han1meViewer-iOS/releases) page
- **Latest build**: the `Han1meViewer-unsigned-ipa` artifact from the most recent successful build under [Actions](https://github.com/pgs666/Han1meViewer-iOS/actions)

Any tool that can re-sign an IPA works: [Impactor](https://github.com/claration/Impactor), AltStore, Sideloadly, native Xcode developer signing, etc. Re-sign with your own Apple ID and install to your device.

> If your device supports [TrollStore](https://github.com/opa334/TrollStore), you can also install the unsigned IPA directly — no re-signing, no expiry.

> Developers who want to build from source should see [docs/BUILDING.md](docs/BUILDING.md).

## 🐛 Issue Reporting

For any problem, bug, or feature suggestion, please open a [GitHub Issue](https://github.com/pgs666/Han1meViewer-iOS/issues). Try to describe the reproduction steps, device model, and OS version clearly.

### Crashes: attach the system crash log

iOS automatically records a diagnostic log for every crash; attaching it greatly helps with diagnosis:

1. Open the system **Settings**
2. Go to **Privacy & Security** → **Analytics & Improvements** → **Analytics Data**
3. **Search** the list for `Han1meViewer` (or the app name)
4. Open the **most recent** entry by date
5. Tap the share button in the top right and **Save to Files**
6. **Upload** the saved log file to the relevant GitHub Issue

> This analytics data is stored locally on your device only; the developer can see it only after you manually export it and attach it to the issue.

### In-app diagnostic log (recommended)

Besides the system crash log, the app keeps an **action diagnostic log** that records screen navigation and key operations (already redacted — it does **not** contain your account, cookies, tokens, or other sensitive information). It is very helpful for diagnosing non-crash problems (freezes, malfunctions, etc.).

How to get it (either way):

- **Export in-app**: Settings → Diagnostic Log → "Export / Share Log", then share it or save to Files
- **From the Files app**: open the **Files** app → **On My iPhone/iPad** → **Han1meViewer** → **Logs** folder; the `app.log` inside is the one

> The diagnostic log is on by default and can be turned off or cleared under Settings → Diagnostic Log. The log is stored on-device only, rolls over by size and is pruned automatically (kept for about 7 days), and is never uploaded automatically.

## 📄 License

This project is licensed under the [GNU General Public License v3.0](LICENSE). It depends on [KSPlayer](https://github.com/kingslay/KSPlayer) (GPL-3.0), so the work as a whole is under GPL-3.0; the upstream Apache-2.0 portions are attributed to Yenaly and misaka10032w.

Key terms: commercial use / modification / distribution are permitted; copyright notices must be retained; derivative works — and works that link statically or dynamically with this project — must also be released under GPL-3.0 (or a compatible license); complete corresponding source must be provided alongside the binary; no warranty is provided. See [LICENSE](LICENSE) for the full terms.

## ⚖️ Disclaimer

This application has no affiliation, partnership, or authorization relationship with `https://hanime1.me/` or its affiliates.

- The app only retrieves publicly displayed DOM structure information from the target site; it does not access user privacy data or any backend database
- All content is intended solely for technical research, learning, and mobile UX optimization, and must not be used for any illegal purpose
- Copyright of the original video/text/image content belongs to the original site or the original producers/distributors; this app does not store, modify, or claim ownership of any copyrighted content
- The user bears all consequences arising from use

---

[![Star History Chart](https://api.star-history.com/svg?repos=pgs666/Han1meViewer-iOS&type=Date)](https://star-history.com/#pgs666/Han1meViewer-iOS&Date)
