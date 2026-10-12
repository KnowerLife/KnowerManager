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
- Xcode 15+ (проект `KnowerManager.xcodeproj`, схема `KnowerManager`)

## Сборка

```bash
git clone <repo-url>
cd KnowerManager
xcodebuild -project KnowerManager.xcodeproj -scheme KnowerManager -configuration Debug build
```

Либо откройте `KnowerManager.xcodeproj` в Xcode и запустите схему `KnowerManager`.

## ⚠️ Крупные бинарные ресурсы не хранятся в git

Три файла исключены из репозитория (см. `.gitignore`) и **должны быть добавлены в папку `KnowerManager/` вручную**, иначе приложение не сможет запустить Xray и разрешать `geoip:`/`geosite:`:

| Файл | Назначение | Откуда взять |
|------|-----------|--------------|
| `KnowerManager/xray-core` | исполняемый файл Xray (arm64/x86_64) | [XTLS/Xray-core releases](https://github.com/XTLS/Xray-core/releases) |
| `KnowerManager/geoip.dat` | база GeoIP для правил маршрутизации | [Loyalsoldier/v2ray-rules-dat releases](https://github.com/Loyalsoldier/v2ray-rules-dat/releases) |
| `KnowerManager/geosite.dat` | база доменов для правил маршрутизации | [Loyalsoldier/v2ray-rules-dat releases](https://github.com/Loyalsoldier/v2ray-rules-dat/releases) |

После копирования выдайте права на выполнение бинарнику:

```bash
chmod +x KnowerManager/xray-core
```

> Файл `tpws` для режима обхода скачивается и собирается приложением самостоятельно
> (кнопка загрузки в разделе «Обход»): https://github.com/bol-van/zapret

## Структура проекта

```
KnowerManager/
├── App/            # Точка входа и главные View (KnowerApp, ContentView, MiniMenu, AboutView)
├── Core/           # Ядро: KnowerManager, SettingsManager, MenuBarManager, Routing/General sheets
├── VPN/            # Xray-клиент: сервис, генератор конфигов, парсеры, модели, UI
├── WARP/           # Генератор WARP-конфигов (Models / Services / Views)
├── OCR/            # Захват экрана и OCR
├── Services/       # AI, PAC-сервер, Watch, Diagnostics
├── Tools/          # Пинг, тест скорости, сканер IP, hostlist, лог трафика
└── Assets.xcassets/
```

## Конфиденциальность

- Пароль пользователя `sudo` и API-ключи AI-провайдеров хранятся в **Keychain**, а не в `UserDefaults`.

## Лицензия

Не указана. Добавьте файл `LICENSE` при необходимости.
