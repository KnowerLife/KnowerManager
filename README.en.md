# Knower Manager

[Русский](README.md) · **English**

[![Build](https://github.com/KnowerLife/KnowerManager/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/KnowerLife/KnowerManager/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS 13.5+](https://img.shields.io/badge/macOS-13.5%2B-blue.svg)](#requirements)

**Knower Manager** is a compact macOS menu-bar app that combines two tools in a single 380 pt window:

- 🖥 **OCR scanner** — on-device text recognition powered by **Apple Vision**, with speech and AI post-processing;
- 🔒 **VPN client** — connectivity through **Xray**: VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC and more.

Everything is a click away from the menu bar: tabs, screen-area capture, toggles, language and theme. See [CHANGELOG.md](CHANGELOG.md) for the release history.

---

## Screenshots

<p align="center">
  <img src="docs/screenshots/main-vpn.png" alt="VPN module — Xray client" width="210"/>
  <img src="docs/screenshots/main-ocr.png" alt="OCR module — text recognition" width="210"/>
</p>
<p align="center">
  <img src="docs/screenshots/tray-menu.png" alt="Menu-bar app menu" width="250"/>
</p>

*From left to right: VPN (Xray), the OCR scanner, and the menu-bar menu. Screenshots taken on macOS 27.*

---

## Table of contents

- [Features](#features)
  - [OCR & Scanner](#ocr--scanner)
  - [VPN (Xray)](#vpn-xray)
  - [App & UI](#app--ui)
- [Requirements](#requirements)
- [Build](#build)
- [Large binary assets (Git LFS)](#large-binary-assets-git-lfs)
- [Project structure](#project-structure)
- [Localization & themes](#localization--themes)
- [Privacy](#privacy)
- [License](#license)
- [Disclaimer](#disclaimer)

---

## Features

### OCR & Scanner

On-device text recognition powered by **Apple Vision**.

- **Capture:** screen area, full screen, clipboard.
- **Import:** image files, PDFs, scanning from a connected scanner (ImageCaptureCore).
- **Multi-page mode** with page history and per-page re-recognition.
- **Languages:** 24 recognition languages — RU, EN, DE, FR, ES, IT, PT, UK, PL, TR, NL, SV, DA, NO, FI, CS, ZH‑Hans, ZH‑Hant, JA, KO, AR, HE, TH, VI. Automatic language detection.
- **Fine-grained options:** accurate/fast recognition level, language correction, custom words, minimum text height, image orientation, show text boxes, barcode detection.
- **Image preprocessing:** grayscale, contrast, brightness, sharpness, invert, threshold binarization, upscale.
- **Export:** TXT, Markdown, JSON, searchable PDF. "Use embedded PDF text" option (extract the existing text layer without recognition).
- **Speech (TTS):** choose the **speech language** (independent of the text language) and voice, plus rate; pause / resume / stop. The language follows the text or can be set manually.
- **Text & recognition language at the result:** the language badge opens a menu (set the text language manually or revert to auto-detection — it also affects speech); "Recognize again" re-runs recognition for the page in the selected language.
- **AI post-processing:** Rewrite, Improve, Summarize, Translate, Fix grammar, Expand, Formal / Informal style, Translate to Russian.
  Providers: **DeepSeek**, **OpenAI**, **Anthropic**, local **Ollama**. DeepSeek balance display.

### VPN (Xray)

A client built on **Xray-core** with its own config generator.

- **Protocols:** VLESS (Reality, Vision, gRPC, WS, HTTPUpgrade, SplitHTTP, H2, KCP, QUIC), VMess, Trojan, Shadowsocks (SIP002 and legacy), Hysteria2, TUIC, SOCKS5, HTTP(S).
- **Import:** link from clipboard, file, URL, **QR code** from an image (Vision). Export a profile as a QR code.
- **Subscriptions:** add by URL, auto-update (checked every 5 minutes), traffic and expiry (`subscription-userinfo`), custom User-Agent, stable profile IDs across updates.
- **Connectivity checks:** TCP ping, sort by ping, "deep" scan (parallel workers, each starts Xray on its own port and probes connectivity via curl).
- **Real proxy test:** latency (HEAD 204 over SOCKS) and download speed (8 MB, speed.cloudflare.com).
- **Live Xray log:** stdout/stderr captured into a ring buffer, collapsible panel.
- **Routing rules** in the Xray style: domains, IPs, ports, protocols (http/tls/quic/bittorrent), action (proxy / direct / block), network (tcp/udp/tcp+udp). Add, edit, duplicate, reorder; rules without conditions are skipped during generation.
- **Profile management:** search, filter by source (all / manual / a specific subscription), multi-select, manual add and edit.

### App & UI

- **Menu-bar icon (tray)** with a popover: open tabs (VPN / OCR), capture screen area, toggles for "notifications", "hide Dock icon", "launch at login", language and theme selection, the "About" window, and Quit.
- **Two tabs:** VPN (Xray) and OCR — in a 380 pt window with height adapting to content.
- **Themes:** system / light / dark.
- **UI languages:** Russian and English.
- "Forget saved administrator password" in settings.

---

## Requirements

- **macOS 13.5** (Ventura) or later.
- **Xcode 16** or later (project `KnowerManager.xcodeproj`, scheme `KnowerManager`).

---

## Build

Large assets are stored in **Git LFS**, so install LFS first:

```bash
brew install git-lfs
git lfs install
```

Then:

```bash
git clone git@github.com:KnowerLife/KnowerManager.git
cd KnowerManager
xcodebuild -project KnowerManager.xcodeproj -scheme KnowerManager -configuration Debug build
```

If the repository was cloned without LFS, fetch the assets:

```bash
git lfs pull
```

Or open `KnowerManager.xcodeproj` in Xcode and run the **KnowerManager** scheme.

The built `.app` will appear in `DerivedData` (or in `Products` when building from Xcode).

---

## Versioning

The version (`MARKETING_VERSION`) and build (`CURRENT_PROJECT_VERSION`) live in
`KnowerManager.xcodeproj/project.pbxproj` and are picked up automatically by the
generated `Info.plist` (`GENERATE_INFOPLIST_FILE = YES`).

**Every update bumps both**: the build always `+1`, the version `+1` in the last
component (patch). Example: `3.0 (31) → 3.0.1 (32)`.

This is done by a script (it also keeps the `CHANGELOG.md` header in sync):

```bash
scripts/bump_version.sh             # build +1, patch +1   (default)
scripts/bump_version.sh --minor     # build +1, minor +1    (3.0.1 → 3.1)
scripts/bump_version.sh --major     # build +1, major +1    (3.1 → 4.0)
scripts/bump_version.sh --build-only
scripts/bump_version.sh --set 3.2.1 # explicit version + build +1
```

So it is never forgotten, install the git hook after cloning — it bumps the
version and build automatically before every commit:

```bash
scripts/install_hooks.sh
```

Skip the bump for a single commit: `git commit --no-verify` or
`SKIP_VERSION_BUMP=1 git commit ...`.

---

## Releases

Releases are published by `.github/workflows/release.yml` in two ways:

1. **Manually** — GitHub → **Actions** → **Release** → *Run workflow* → pick how to
   bump the version (`patch` / `minor` / `major` / `none`). The workflow bumps the
   version and build, commits, creates a `vX.Y.Z` tag, runs the tests, builds
   `KnowerManager.app`, zips it and creates a GitHub Release.
2. **By tag** — `git tag v3.0.2 && git push origin v3.0.2`. The version comes from
   the tag, no bump is performed; the workflow builds and publishes a Release for it.

The in-app update check ("Settings → Check for updates") reads the releases list
via the GitHub API and compares the tag (`vX.Y.Z`) with `CFBundleShortVersionString`.
For an update to show up there must be a **release whose tag is newer than the
installed version**.

> The CI build is **unsigned** (`CODE_SIGNING_ALLOWED=NO`). On first launch macOS
> may show a Gatekeeper warning. To clear the quarantine:
> `xattr -dr com.apple.quarantine /path/to/KnowerManager.app`.

---

## Large binary assets (Git LFS)

Three files are stored in the repository via **Git LFS** (see `.gitattributes`):

| File | Purpose | Where to get it |
|------|---------|-----------------|
| `KnowerManager/Resources/Binaries/xray-core` | Xray executable (universal: arm64 + x86_64) | [XTLS/Xray-core releases](https://github.com/XTLS/Xray-core/releases) |
| `KnowerManager/Resources/Data/geoip.dat` | GeoIP database for routing rules | [Loyalsoldier/v2ray-rules-dat releases](https://github.com/Loyalsoldier/v2ray-rules-dat/releases) |
| `KnowerManager/Resources/Data/geosite.dat` | Domain database for routing rules | [Loyalsoldier/v2ray-rules-dat releases](https://github.com/Loyalsoldier/v2ray-rules-dat/releases) |

Clone with Git LFS installed and the files are fetched automatically. If LFS is unavailable, download the files manually to the paths in the table and make the binary executable:

```bash
chmod +x KnowerManager/Resources/Binaries/xray-core
```

---

## Project structure

```
KnowerManager/
├── App/            # Entry point and main views (KnowerApp, ContentView, MiniMenu, AboutView)
├── Core/           # Core: SettingsManager, MenuBarManager, PrivilegedRunner, GeneralSettingsSheet
├── Design/         # Design system and tokens (DesignTokens, Components, UXUIKit, NeonTheme…)
├── Language/       # Localization: StringKey + LocalizationRU/LocalizationEN
├── VPN/            # Xray client
│   ├── Models/      # Profiles, subscriptions, Shadowsocks models
│   ├── Parsers/     # SS, VMess, VLESS, Hysteria2, TUIC, SOCKS/HTTP + LinkParser
│   ├── Routing/     # Routing rules (RoutingManager, RoutingView, RoutingRuleEditor)
│   ├── Services/    # XrayService, XrayConfigGenerator, SubscriptionManager, ProfileProxyTester
│   ├── Utils/       # LinkParser, LinkExporter, QRCodeService, TCPPing
│   └── Views/       # SSConnectionView, SubscriptionsView, ProfileEditView, QRExport, SpeedTest
├── OCR/            # Screen capture, recognition, speech, export
│   ├── Models/      # OCR models and options (languages, preprocessing, TTS, export formats)
│   ├── Services/    # OCRManager, OCRService, SpeechService, DocumentImportService…
│   ├── Utils/       # ScreenCaptureService, ScannerDeviceView
│   └── Views/       # ScannerView, OCRSheets
├── Services/       # AI (AIService), Keychain (KeychainHelper)
└── Resources/      # Assets.xcassets, Binaries and Data (in Git LFS)
```

---

## Localization & themes

- All user-facing strings live in `KnowerManager/Language/`:
  `StringKey` (keys) + `LocalizationRU` / `LocalizationEN` (translations).
  To add a string, add a case to `StringKey` and a value to both files.
- Russian and English UI languages, plus system / light / dark themes.

---

## Privacy

- AI provider API keys and the administrator (`sudo`) password are stored in the **Keychain**, not in `UserDefaults`.
- VPN profiles, routing rules and subscriptions are stored locally (`UserDefaults` / Application Support).
- The app does **not** send your data to third parties, except for direct requests to the services you choose (AI provider, subscription and connectivity-check servers).

---

## License

Released under the **MIT** license — see [LICENSE](LICENSE).

---

## Disclaimer

The app is provided "as is", without warranty. You are solely responsible for complying with local laws and the terms of the networks and services you use.