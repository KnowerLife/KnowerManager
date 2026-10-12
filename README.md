# KnowerManager

macOS-приложение в строке меню для обхода блокировок и работы с прокси/VPN.

## Возможности

- **Обход (Zapret / tpws)** — локальный SOCKS-прокси с набором стратегий обхода DPI, режимами маршрутизации (Global / OnlyList / Exclude), Kill Switch (pf).
- **VPN (Xray)** — клиент VLESS / VMess / Trojan / Shadowsocks / Hysteria2 / TUIC / SOCKS5 / HTTP с импортом из буфера, файла, URL и QR-кода, подписками с автообновлением, пингом, «глубоким» сканированием, реальным тестом через прокси (задержка + скорость), живым логом Xray и режимами маршрутизации.
- **WARP** — генератор конфигураций WARP/AmneziaWG (Clash, Sing-Box, WireGuard, Amnezia).
- **OCR + AI** — распознавание текста с экрана и обработка текста через AI-провайдеров (DeepSeek, OpenAI, Anthropic, локальный Ollama).
- **Инструменты** — мониторинг пинга, тест скорости, сканер IP, редактор hostlist, диагностика, лог трафика.
- **KnowerWatch** — автовосстановление соединения и уведомления.

## Возможности VPN (Xray)

- **Протоколы:** VLESS (Reality, Vision, gRPC, WS, HTTPUpgrade, SplitHTTP, H2, KCP, QUIC), VMess, Trojan, Shadowsocks (SIP002 + legacy), Hysteria2, TUIC, SOCKS5, HTTP(S).
- **Подписки:** добавление по URL, автообновление по расписанию, отображение трафика и срока действия (subscription-userinfo), стабильные ID профилей при обновлении.
- **QR-коды:** экспорт профиля в QR (контекстное меню → «QR код»), импорт из буфера обмена или файла изображения (Vision framework).
- **Реальный тест через прокси:** запуск Xray на временном порту, измерение задержки (HEAD 204 через SOCKS) и скорости загрузки (8 МБ через speed.cloudflare.com).
- **Живой лог Xray:** захват stdout/stderr в кольцевой буфер (400 строк), сворачиваемая панель в карточке VPN.
- **Глубокое сканирование:** 24 параллельных воркера, каждый запускает Xray на своём порту и проверяет связность через curl.

## Требования

- macOS 13.5 (Ventura) или новее
- Xcode 16 или новее (проект `KnowerManager.xcodeproj`, схема `KnowerManager`)

## Сборка

Крупные ресурсы проекта хранятся в Git LFS, поэтому сначала установите LFS:

```bash
brew install git-lfs
git lfs install
```

Затем:

```bash
git clone <repo-url>
cd KnowerManager
xcodebuild -project KnowerManager.xcodeproj -scheme KnowerManager -configuration Debug build
```

Если репозиторий уже склонирован без LFS — подтяните ресурсы командой `git lfs pull`.

Либо откройте `KnowerManager.xcodeproj` в Xcode и запустите схему `KnowerManager`.

## Крупные бинарные ресурсы (Git LFS)

Три файла хранятся в репозитории через **Git LFS** (см. `.gitattributes`):

| Файл | Назначение | Откуда взять |
|------|-----------|--------------|
| `KnowerManager/Resources/Binaries/xray-core` | исполняемый файл Xray (universal: arm64 + x86_64) | [XTLS/Xray-core releases](https://github.com/XTLS/Xray-core/releases) |
| `KnowerManager/Resources/Data/geoip.dat` | база GeoIP для правил маршрутизации | [Loyalsoldier/v2ray-rules-dat releases](https://github.com/Loyalsoldier/v2ray-rules-dat/releases) |
| `KnowerManager/Resources/Data/geosite.dat` | база доменов для правил маршрутизации | [Loyalsoldier/v2ray-rules-dat releases](https://github.com/Loyalsoldier/v2ray-rules-dat/releases) |

Склонируйте с установленным Git LFS, и файлы подтянутся автоматически. Если LFS недоступен —
скачайте файлы вручную по путям из таблицы и выдайте права на выполнение бинарнику:

```bash
chmod +x KnowerManager/Resources/Binaries/xray-core
```

> Файл `tpws` для режима обхода скачивается и собирается приложением самостоятельно
> (кнопка загрузки в разделе «Обход»): https://github.com/bol-van/zapret

## Структура проекта

```
KnowerManager/
├── App/            # Точка входа и главные View (KnowerApp, ContentView, MiniMenu, AboutView)
├── Core/           # Ядро: KnowerManager, SettingsManager, MenuBarManager, Routing/General sheets
├── VPN/            # Xray-клиент: Models / Parsers / Routing / Services / Utils / Views
│   ├── Parsers/     # SS, VMess, VLESS, Hysteria2, TUIC, SOCKS/HTTP + LinkParser
│   ├── Services/    # XrayService, SubscriptionManager, ProfileProxyTester
│   ├── Utils/       # LinkParser, LinkExporter, QRCodeService, TCPPing
│   └── Views/       # SSConnectionView, SubscriptionsView, ProfileEditView, ProfileQRExportView, ProfileSpeedTestView
├── WARP/           # Генератор WARP-конфигов (Models / Services / Views)
├── OCR/            # Захват экрана и OCR (Models / Services / Utils)
├── Services/       # AI, Keychain, PAC-сервер, Watch, Diagnostics
├── Tools/          # Пинг, тест скорости, сканер IP, hostlist, лог трафика (Core / Views)
└── Resources/      # Assets.xcassets, Binaries и Data (в Git LFS)
```

## Конфиденциальность

- Пароль пользователя `sudo` и API-ключи AI-провайдеров хранятся в **Keychain**, а не в `UserDefaults`.

## Лицензия

Проект распространяется под лицензией **MIT** — см. файл [LICENSE](LICENSE).
