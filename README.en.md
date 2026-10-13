# Knower Manager

[Русский](README.md) · **English**

[![Build](https://github.com/KnowerLife/KnowerManager/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/KnowerLife/KnowerManager/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS 13.5+](https://img.shields.io/badge/macOS-13.5%2B-blue.svg)](#requirements)

**A compact macOS menu-bar app:** an OCR scanner with speech and AI post-processing, an **Xray**-based VPN client, and a **WARP / AmneziaWG** config generator — three modules in a single 380 pt window, plus quick access from the menu bar.

> The former "Bypass" (Zapret/tpws) and "Tools" modules have been removed. The app now ships **OCR · VPN · WARP**.

---

## Table of contents

- [Features](#features)
  - [OCR & Scanner](#ocr--scanner)
  - [VPN (Xray)](#vpn-xray)
  - [WARP / AmneziaWG](#warp--amneziawg)
  - [App & UI](#app--ui)
- [Requirements](#requirements)
- [Build](#build)
- [Large binary assets (Git LFS)](#large-binary-assets-git-lfs)
- [Project structure](#project-structure)
- [Localization & themes](#localization--themes)
- [Privacy](#privacy)
- [License](#license)

---

## Features

### OCR & Scanner

Text recognition powered by **Apple Vision**.

- **Capture:** screen area, full screen, clipboard.
- **Import:** image files, PDFs, scanning from a connected scanner (ImageCaptureCore).
- **Multi-page mode** with history and per-page re-recognition.
- **Languages:** 24 recognition languages — RU, EN, DE, FR, ES, IT, PT, UK, PL, TR, NL, SV, DA, NO, FI, CS, ZH‑Hans, ZH‑Hant, JA, KO, AR, HE, TH, VI. Automatic language detection.
- **Fine-grained options:** accurate/fast recognition level, language correction, custom words, minimum text height, image orientation, show text boxes, barcode detection.
- **Image preprocessing:** grayscale, contrast, brightness, sharpness, invert, threshold binarization, upscale.
- **Export:** TXT, Markdown, JSON, searchable PDF. "Use embedded PDF text" option (extract the existing text layer without recognition).
- **Speech (TTS):** choose the **speech language** (independent of the text language) and voice, plus rate; pause / resume / stop. The language follows the text or can be set manually.
- **Text & recognition language at the result:** the language badge opens a menu (set the text language manually or revert to auto-detection — it also affects speech); "Recognize again" re-runs recognition for the page in the selected language.
- **AI post-processing:** Rewrite, Improve, Summarize, Translate, Fix grammar, Expand, Formal / Informal style, Translate to Russian.
  Providers: **DeepSeek**, **OpenAI**, **Anthropic**, local **Ollama**. DeepSeek balance display.

### VPN (Xray)

- **Protocols:** VLESS (Reality, Vision, gRPC, WS, HTTPUpgrade, SplitHTTP, H2, KCP, QUIC), VMess, Trojan, Shadowsocks (SIP002 and legacy), Hysteria2, TUIC, SOCKS5, HTTP(S).
- **Import:** link from clipboard, file, URL, **QR code** (image or camera — Vision). Export a profile as a QR code.
- **Subscriptions:** add by URL, auto-update (checked every 5 minutes), traffic and expiry (`subscription-userinfo`), User-Agent, stable profile IDs across updates.
- **Connectivity checks:** TCP ping, sort by ping, "deep" scan (parallel workers, each starts Xray on its own port and probes connectivity via curl).
- **Real proxy test:** latency (HEAD 204 over SOCKS) and download speed (8 MB, speed.cloudflare.com).
- **Live Xray log:** stdout/stderr captured into a ring buffer, collapsible panel.
- **Routing rules** in the Xray style: domains, IPs, ports, protocols (http/tls/quic/bittorrent), action (proxy / direct / block), network (tcp/udp/tcp+udp). Add, edit, duplicate, reorder; rules without conditions are skipped during generation.
- **Profile management:** search, filter by source (all / manual / a specific subscription), multi-select, manual add and edit.

### WARP / AmneziaWG

- WARP account registration via the official Cloudflare API.
- **Export formats:** Clash Meta (YAML), AmneziaWG (CONF), Sing‑box (JSON), WireGuard (CONF).
- **AmneziaWG parameters:** Jc, Jmin, Jmax, S1, S2 (plus H1–H4).
- **Routing categories** (for Clash / rule-providers): Porn, Discord, YouTube, Social networks, Torrents, Tools, Music.
- **Endpoint selection:** the IP scanner finds the best node by latency; an endpoint can also be set manually.
- System proxy detection; generation runs locally.

### App & UI

- **Menu-bar icon (tray)** with a popover: open tabs (VPN / WARP / OCR), capture screen area, toggles for "notifications", "hide Dock icon", "launch at login", language and theme selection, the "About" window, and Quit.
- **Three tabs:** VPN (Xray), WARP, OCR — in a 380 pt window with height adapts to content.
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
git clone <repo-url>
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
├── WARP/           # WARP / AmneziaWG generator (Models / Services / Views)
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
- The app does **not** send your data to third parties, except for direct requests to the services you choose (AI provider, Cloudflare WARP API, subscription and connectivity-check servers).

---

## License

Released under the **MIT** license — see [LICENSE](LICENSE).

---

## Disclaimer

The app is provided "as is", without warranty. You are solely responsible for complying with local laws and the terms of the networks and services you use.
