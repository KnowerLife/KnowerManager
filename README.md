# KnowerManager

macOS-приложение в строке меню для обхода блокировок и работы с прокси/VPN.

## Возможности

- **Обход (Zapret / tpws)** — локальный SOCKS-прокси с набором стратегий обхода DPI, режимами маршрутизации (Global / OnlyList / Exclude), Kill Switch (pf).
- **VPN (Xray)** — клиент VLESS / VMess / Trojan / Shadowsocks с импортом из буфера, файла и по URL, пингом и «глубоким» сканированием, режимами маршрутизации.
- **WARP** — генератор конфигураций WARP/AmneziaWG (Clash, Sing-Box, WireGuard, Amnezia).
- **OCR + AI** — распознавание текста с экрана и обработка текста через AI-провайдеров (DeepSeek, OpenAI, Anthropic, локальный Ollama).
- **Инструменты** — мониторинг пинга, тест скорости, сканер IP, редактор hostlist, диагностика, лог трафика.
- **KnowerWatch** — автовосстановление соединения и уведомления.

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
| `KnowerManager/Resources/Binaries/xray-core` | исполняемый файл Xray (arm64/x86_64) | [XTLS/Xray-core releases](https://github.com/XTLS/Xray-core/releases) |
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
