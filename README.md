# Knower Manager

**Русский** · [English](README.en.md)

**Компактное приложение для macOS в строке меню:** OCR-сканер с озвучкой и AI‑обработкой, VPN‑клиент на **Xray** и генератор конфигураций **WARP / AmneziaWG** — три модуля в одном окне шириной 380 pt плюс быстрый доступ из трея.

> Модули «Обход» (Zapret/tpws) и «Инструменты» из приложения удалены. Сейчас поддерживаются **OCR · VPN · WARP**.

---

## Содержание

- [Возможности](#возможности)
  - [OCR и сканер](#ocr-и-сканер)
  - [VPN (Xray)](#vpn-xray)
  - [WARP / AmneziaWG](#warp--amneziawg)
  - [Приложение и интерфейс](#приложение-и-интерфейс)
- [Требования](#требования)
- [Сборка](#сборка)
- [Крупные бинарные ресурсы (Git LFS)](#крупные-бинарные-ресурсы-git-lfs)
- [Структура проекта](#структура-проекта)
- [Локализация и темы](#локализация-и-темы)
- [Конфиденциальность](#конфиденциальность)
- [Лицензия](#лицензия)

---

## Возможности

### OCR и сканер

Распознавание текста на базе **Apple Vision**.

- **Захват:** область экрана, весь экран, буфер обмена.
- **Импорт:** файлы изображений, PDF, сканирование с подключённого сканера (ImageCaptureCore).
- **Многостраничный режим** с историей и перераспознаванием отдельной страницы.
- **Языки:** 24 языка распознавания — RU, EN, DE, FR, ES, IT, PT, UK, PL, TR, NL, SV, DA, NO, FI, CS, ZH‑Hans, ZH‑Hant, JA, KO, AR, HE, TH, VI. Автоопределение языка.
- **Тонкая настройка:** точный/быстрый уровень распознавания, языковая коррекция, пользовательские слова, минимальная высота текста, ориентация изображения, показ рамок текста, определение штрих‑кодов.
- **Предобработка изображения:** ч/б, контраст, яркость, резкость, инверсия, бинаризация с порогом, апскейл.
- **Экспорт:** TXT, Markdown, JSON, PDF с текстовым слоем. Опция «брать текст из PDF» (встроенный слой без распознавания).
- **Озвучка (TTS):** выбор **языка озвучки** (независимо от языка текста) и голоса, скорость; пауза / продолжить / стоп; язык подбирается под текст или задаётся вручную.
- **Язык текста и распознавания у результата:** бейдж языка → меню (задать язык текста вручную или вернуть автоопределение, влияет на озвучку); «Распознать заново» → перераспознать страницу в выбранном языке.
- **AI‑обработка текста:** Переписать, Улучшить, Сократить, Перевести, Исправить орфографию, Расширить, Официальный / Неофициальный стиль, Перевод на русский.
  Провайдеры: **DeepSeek**, **OpenAI**, **Anthropic**, локальный **Ollama**. Отображение баланса DeepSeek.

### VPN (Xray)

- **Протоколы:** VLESS (Reality, Vision, gRPC, WS, HTTPUpgrade, SplitHTTP, H2, KCP, QUIC), VMess, Trojan, Shadowsocks (SIP002 и legacy), Hysteria2, TUIC, SOCKS5, HTTP(S).
- **Импорт:** ссылка из буфера обмена, файл, URL, **QR‑код** (изображение или камера — Vision). Экспорт профиля в QR‑код.
- **Подписки:** добавление по URL, автообновление (проверка каждые 5 минут), трафик и срок действия (`subscription-userinfo`), User-Agent, стабильные ID профилей при обновлении.
- **Проверка соединений:** TCP‑пинг, сортировка по пингу, «глубокое» сканирование (параллельные воркеры, запуск Xray на отдельном порту и проверка связности через curl).
- **Реальный тест через прокси:** задержка (HEAD 204 через SOCKS) и скорость загрузки (8 МБ, speed.cloudflare.com).
- **Живой лог Xray:** захват stdout/stderr в кольцевой буфер, сворачиваемая панель.
- **Правила маршрутизации** в стиле Xray: домены, IP, порты, протоколы (http/tls/quic/bittorrent), действие (прокси / напрямую / блок), сеть (tcp/udp/tcp+udp). Добавление, редактирование, копирование, сортировка; правила без условий пропускаются при генерации.
- **Управление профилями:** поиск, фильтр по источнику (все / ручные / конкретная подписка), мультивыбор, ручное добавление и редактирование.

### WARP / AmneziaWG

- Регистрация WARP‑аккаунта через официальный API Cloudflare.
- **Форматы экспорта:** Clash Meta (YAML), AmneziaWG (CONF), Sing‑box (JSON), WireGuard (CONF).
- **Параметры AmneziaWG:** Jc, Jmin, Jmax, S1, S2 (плюс H1–H4).
- **Категории маршрутизации** (для Clash / rule‑providers): Porn, Discord, YouTube, Соцсети, Торренты, Инструменты, Музыка.
- **Подбор endpoint:** сканер IP ищет лучший узел по задержке; можно задать endpoint вручную.
- Определение системного прокси; генерация выполняется локально.

### Приложение и интерфейс

- **Иконка в строке меню (трей)** с popover: быстрое открытие вкладок (VPN / WARP / OCR), захват области экрана, переключатели «уведомления», «скрыть иконку в Dock», «запуск при входе», выбор языка и темы, окно «О программе», выход.
- **Три вкладки:** VPN (Xray), WARP, OCR — в окне шириной 380 pt с адаптивной высотой под содержимое.
- **Темы:** системная / светлая / тёмная.
- **Языки интерфейса:** русский и английский.
- «Забыть сохранённый пароль администратора» в настройках.

---

## Требования

- **macOS 13.5** (Ventura) или новее.
- **Xcode 16** или новее (проект `KnowerManager.xcodeproj`, схема `KnowerManager`).

---

## Сборка

Крупные ресурсы проекта хранятся в **Git LFS**, поэтому сначала установите LFS:

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

Если репозиторий уже склонирован без LFS — подтяните ресурсы:

```bash
git lfs pull
```

Либо откройте `KnowerManager.xcodeproj` в Xcode и запустите схему **KnowerManager**.

Готовый `.app` появится в `DerivedData` (или в `Products` при сборке из Xcode).

---

## Крупные бинарные ресурсы (Git LFS)

Три файла хранятся в репозитории через **Git LFS** (см. `.gitattributes`):

| Файл | Назначение | Откуда взять |
|------|-----------|--------------|
| `KnowerManager/Resources/Binaries/xray-core` | исполняемый файл Xray (universal: arm64 + x86_64) | [XTLS/Xray-core releases](https://github.com/XTLS/Xray-core/releases) |
| `KnowerManager/Resources/Data/geoip.dat` | база GeoIP для правил маршрутизации | [Loyalsoldier/v2ray-rules-dat releases](https://github.com/Loyalsoldier/v2ray-rules-dat/releases) |
| `KnowerManager/Resources/Data/geosite.dat` | база доменов для правил маршрутизации | [Loyalsoldier/v2ray-rules-dat releases](https://github.com/Loyalsoldier/v2ray-rules-dat/releases) |

Склонируйте с установленным Git LFS — файлы подтянутся автоматически. Если LFS недоступен, скачайте файлы вручную по путям из таблицы и выдайте права на выполнение бинарнику:

```bash
chmod +x KnowerManager/Resources/Binaries/xray-core
```

---

## Структура проекта

```
KnowerManager/
├── App/            # Точка входа и главные View (KnowerApp, ContentView, MiniMenu, AboutView)
├── Core/           # Ядро: SettingsManager, MenuBarManager, PrivilegedRunner, GeneralSettingsSheet
├── Design/         # Дизайн-система и токены (DesignTokens, Components, UXUIKit, NeonTheme…)
├── Language/       # Локализация: StringKey + LocalizationRU/LocalizationEN
├── VPN/            # Xray-клиент
│   ├── Models/      # Профили, подписки, Shadowsocks-модели
│   ├── Parsers/     # SS, VMess, VLESS, Hysteria2, TUIC, SOCKS/HTTP + LinkParser
│   ├── Routing/     # Правила маршрутизации (RoutingManager, RoutingView, RoutingRuleEditor)
│   ├── Services/    # XrayService, XrayConfigGenerator, SubscriptionManager, ProfileProxyTester
│   ├── Utils/       # LinkParser, LinkExporter, QRCodeService, TCPPing
│   └── Views/       # SSConnectionView, SubscriptionsView, ProfileEditView, QRExport, SpeedTest
├── WARP/           # Генератор WARP / AmneziaWG (Models / Services / Views)
├── OCR/            # Захват экрана, распознавание, озвучка, экспорт
│   ├── Models/      # OCR-модели и опции (языки, предобработка, TTS, форматы экспорта)
│   ├── Services/    # OCRManager, OCRService, SpeechService, DocumentImportService…
│   ├── Utils/       # ScreenCaptureService, ScannerDeviceView
│   └── Views/       # ScannerView, OCRSheets
├── Services/       # AI (AIService), Keychain (KeychainHelper)
└── Resources/      # Assets.xcassets, Binaries и Data (в Git LFS)
```

---

## Локализация и темы

- Все пользовательские строки вынесены в папку `KnowerManager/Language/`:
  `StringKey` (ключи) + `LocalizationRU` / `LocalizationEN` (переводы).
  Чтобы добавить строку — заведите кейс в `StringKey` и перевод в обоих файлах.
- Поддерживаются русский и английский языки интерфейса, а также системная / светлая / тёмная темы.

---

## Конфиденциальность

- API‑ключи AI‑провайдеров и пароль администратора (`sudo`) хранятся в **Keychain**, а не в `UserDefaults`.
- Профили VPN, правила маршрутизации и подписки хранятся локально (в `UserDefaults` / `Application Support`).
- Приложение **не отправляет** ваши данные третьим лицам, кроме прямых запросов к выбранным вами сервисам (AI‑провайдер, Cloudflare WARP API, серверы подписок и проверок соединений).

---

## Лицензия

Проект распространяется под лицензией **MIT** — см. файл [LICENSE](LICENSE).

---

## Отказ от ответственности

Приложение предоставляется «как есть», без гарантий. Пользователь самостоятельно несёт ответственность за соблюдение местного законодательства и правил использования сетей и сервисов.
