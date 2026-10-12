import SwiftUI
import Combine
import ServiceManagement
import UserNotifications

// MARK: - Enums for Settings

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
    
    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .russian:
            switch self {
            case .system: return "Системная"
            case .light: return "Светлая"
            case .dark: return "Темная"
            }
        case .english:
            return self.rawValue
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "Русский"
    case english = "English"
    
    var id: String { self.rawValue }
}

enum DNSServer: String, CaseIterable, Identifiable {
    case system = "System"
    case cloudflare = "Cloudflare"
    case google = "Google"
    case adguard = "AdGuard"
    var id: String { rawValue }
    
    var servers: String {
        switch self {
        case .system: return "Empty"
        case .cloudflare: return "1.1.1.1 1.0.0.1"
        case .google: return "8.8.8.8 8.8.4.4"
        case .adguard: return "94.140.14.14 94.140.15.15"
        }
    }
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @AppStorage("appTheme") var currentTheme: AppTheme = .system
    @AppStorage("appLanguage") var currentLanguage: AppLanguage = .russian
    @AppStorage("dnsServer") var dnsServer: DNSServer = .system
    @AppStorage("killSwitchEnabled") var killSwitchEnabled: Bool = false
    
    // Fixes
    @AppStorage("fixYoutube") var fixYoutube: Bool = true
    @AppStorage("fixDiscord") var fixDiscord: Bool = true
    
    // Automation
    @AppStorage("showNotifications") var showNotifications: Bool = true
    
    // Dock Icon Logic
    @AppStorage("hideDockIcon") var hideDockIcon: Bool = false {
        didSet {
            updateDockIconVisibility()
        }
    }
    
    @AppStorage("launchAtLogin") var isLaunchAtLoginEnabled: Bool = false {
        didSet { toggleLaunchAtLogin(enabled: isLaunchAtLoginEnabled) }
    }
    
    init() {
        updateDockIconVisibility()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func updateDockIconVisibility() {
        DispatchQueue.main.async {
            if self.hideDockIcon {
                NSApp.setActivationPolicy(.accessory)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
    
    private func toggleLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            try? (enabled ? service.register() : service.unregister())
        }
    }
    
    func sendNotification(title: String, body: String) {
        guard showNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func t(_ key: StringKey) -> String {
        return key.localized(lang: currentLanguage)
    }
}

// MARK: - Localization Keys

enum StringKey {
    // --- Global ---
    case appTitle
    
    // --- General Settings ---
    case settingsTitle, settingsGeneral, settingsAppearance
    case launchAtLogin, launchAtLoginDesc
    
    // --- Quick Fixes ---
    case fixesTitle, fixYoutube, fixDiscord
    
    // --- Statuses (Knower) ---
    case statusWaiting, statusReady, statusMissing, statusDownloading, statusError, statusStarting
    case statusActive, statusStopped, statusActiveShort
    case statusProtectionActive, checking
    case autoFound, notFound
    
    // --- Statuses (WARP) ---
    case proxyScan, proxyDirect, proxyFound
    case statusGenerating, statusSuccess, statusSaved, statusCopied
    case errorPrefix
    
    // --- Tabs (TopBar) ---
    case tabBypass, tabWarp, tabScanner, tabTools

        
    // --- Mini Menu ---
    case mmOn, mmOff, mmSecureOff
    case mmScanShort, mmDnsShort, mmSettingsShort
    case mmCopied
        
    // --- Warp Routing Rules (Models) ---
    case rulePorno, ruleDiscord, ruleYoutube, ruleSocials
    case ruleTorrent, ruleTools, ruleMusic
        
    // --- Tools UI ---
    case toolsNoMonitors, toolsAddTargetPlh
    case pingGoogle, pingCloudflare
        
    // --- Scanner UI Extra ---
    case ocrLabelImage, ocrCharsCount, ocrHelpClearAll, ocrHelpCloseImage
        
    // --- Warp Status Extra ---
    case warpProxyAuto, warpProxyDirect
    
    // --- Buttons ---
    case btnAutoInstall, btnManualInstall, btnAutoCheck
    case btnStart, btnStop
    case btnCopy, btnScan, btnGenerate, btnSaveFile, btnDone, btnCancel, btnSave
    
    // --- Main UI Headers & Labels ---
    case titleStrategy, titleLog, titleDNS
    case setupTitle, setupDesc
    case dashboardPing, dashboardGraph
    
    // --- Routing ---
    case routingTitle, routingDesc, routingModeGlobal, routingModeList
    case routingAddPlaceholder, routingAddBtn, routingListHeader
    
    // --- Strategies ---
    case stratSplit2, stratDisorder, stratFake, stratOOB, stratSplit1, stratAuto
    case stratCustom, stratCustomPlaceholder
    
    // --- Terminal Logs ---
    case logScanStarted, logTargets, logTest, logResult, logWinner, logAccessApplied, logNoStrategy
    case logProxyStarted, logInstallSuccess, logBuildError
    
    // --- WARP Generator UI ---
    case warpTitle, warpFormat
    case warpGenSettings
    
    // --- WARP Settings Sheet ---
    case warpMethod
    case methodLocal, methodSSH
    case sshHost, sshUser, sshPort, sshPass
    case warpParams
    case warpRouting
    
    // --- QR Code ---
    case qrTitle, qrNotGenerated, qrScanHint
    
    // --- About Window ---
    case aboutPowered, aboutVersion, aboutCopyright
    
    // --- Menu Bar ---
    case menuStatusLabel, menuLanguage, menuTheme, menuAbout, menuOpen, menuQuit
    
    // --- IP Scanner (Renamed to avoid conflict) ---
    case ipScanTitle, ipScanBestIP, ipScanStart, ipScanButton
    case endpointAuto, endpointScanHelp
    case qrFailedTitle, qrFailedDesc, qrScanImport
    case btnShare, btnSaved
    
    // --- Tools ---
    case toolsTitle, toolsSpeedTest, toolsHostlist, toolsTraffic
    case speedDownload, speedRun, speedTesting
    case hostPlaceholder, hostAdd, hostLoadPopular, hostSave
    case logMonitor, logClear, logTime, logDomain, logStatus
    
    // --- General Settings Extra ---
    case hideDockTitle, hideDockDesc
    
    // --- Automation Settings ---
    case automationTitle
    case notificationsTitle, notificationsDesc
    case hostSaveMessage
    
    // --- KnowerWatch (Auto-Heal) ---
    case kwTitle, kwDesc
    case kwNotificationTitle, kwRestoredBody
    case kwSearchingStatus
    
    // --- OCR & AI Scanner (Main) ---
    case ocrTitle, ocrStart, ocrArea, ocrScreen, ocrClipboard
    case ocrLang, ocrHistory, ocrResult, ocrAI, ocrAISettings
    case ocrCopy, ocrClear
    case ocrSaveImageTitle
    case aiEnable, aiProvider, aiApiKey, aiModel
    
    // --- OCR Statuses & Errors ---
    case ocrStatusReady, ocrCapturing, ocrCancel, ocrRecognizing, ocrDone
    case ocrAIDisabled, ocrAIProcessing, ocrAIDone, ocrAIErrorPrefix
    case ocrCopied, ocrCleared, ocrHistoryLoaded, ocrSaveTitle, ocrSaveError
    
    // --- Screen Capture Permissions ---
    case scPermTitle, scPermOpenSettings, scPermLater
    case scErrPermission, scErrFailed, scErrCancelled
    
    // --- New Features (Diagnostics, Presets, Builder) ---
    case diagTitle, diagCheckBtn, diagPlaceholder, diagSuccess, diagFail
    case flushDnsBtn, flushDnsSuccess
    case presetsTitle, presetSocials, presetMedia, presetNews
    case builderTitle, builderSplit, builderDisorder, builderFake, builderTtl
    case menuQuitShort, menuOpenShort
    case killSwitchTitle, killSwitchDesc
    
    // --- OCR Languages ---
    case langRu, langEn, langDe, langFr, langEs
    
    // --- AI Operations ---
    case aiOpRewrite, aiOpImprove, aiOpSummarize, aiOpTranslate, aiOpGrammar
    case aiOpExpand, aiOpFormal, aiOpInformal, aiOpTranslateRu
    
    // --- AI Prompts ---
    case aiPromptRewrite, aiPromptImprove, aiPromptSummarize, aiPromptTranslate
    case aiPromptGrammar, aiPromptExpand, aiPromptFormal, aiPromptInformal, aiPromptTranslateRu
    
    // --- AI Errors ---
    case aiErrConfig, aiErrEmpty, aiErrNetwork, aiErrApi
    
    case previewLabel, previewClose
    case btnRefresh
    case btnCopyImage, btnSaveImage
    case warpFieldEndpoint, warpFieldLicense, sshPassPlaceholder
    
    case statusProtected, statusDisconnected
    
    // --- Gateway Card ---
    case gatewayActive
    case gatewayWaiting, gatewayEnableHint
    case btnOpenSettings
    
    case scanResults, btnUse
    
    case faqWandQ, faqWandA
    case faqRouteQ, faqRouteA
    case faqFixQ, faqFixA
    case faqGatewayQ, faqGatewayA
    case faqKwQ, faqKwA
    case faqOcrQ, faqOcrA
    case faqWarpQ, faqWarpA
    case faqToolsQ, faqToolsA
    case faqAiQ, faqAiA
    
    case passTitle, passDesc, passPlaceholder
    case passRemember, passForget
    
    case fixYtTitle, fixDsTitle, gatewayTitle
    
    // Новые стратегии
    case stratFlowseal, stratTlsRec
        
    // Импорт / Экспорт
    case importMessage, exportMessage
        
    // Логи и Статусы
    case logPacServer, logFwUpdated, logGatewayBlocked
    case statusStoppedKS
        
    // Ошибки пароля и кнопки
    case passIncorrect, passCancelled, btnOK
    
    case btnImport
    case routingGlobalDesc
    
    case routingModeExclude
    case urlPlaceholder, btnDownload, downloadSuccess, downloadError
    
    case stratseqOverl, stratmultiDisorder
    
    case vpnTitle
    case vpnProfilesLoaded
    case vpnConnected
    case vpnImportClipboard
    case vpnImportFile
    case vpnDeleteAll
    case vpnPingAll
    case vpnSearchPlaceholder
    case vpnNoProfiles
    case btnConnect
    case btnDisconnect
    case vpnImportUrl
    case vpnRemoveDead
    case vpnEnterUrlTitle
    case vpnEnterUrlPlaceholder
    case vpnSortByPing
    case checkHTTP
    case vpnOpenDataFolder
    case vpnDeepScan
    case vpnStopScan
    case vpnImporting
    case vpnDeepScanningTitle
    case vpnDeepScanningSubtitle
    case vpnCheckAll
    case contextDelete
    case contextConnect
    case contextDisconnect
    case contextFavorite
    case contextUnfavorite
    case vpnLatencyDead
    case contextPing
    case btnPingSelected
    case contextEdit
    case editTitle
    case labelName
    case labelServer
    case labelPort
    case labelUUID // или Пароль
    case labelMethod // или Security
    case labelProtocol
    case labelNetwork
    case labelFlow
    case labelEncryption
    case labelServiceName
    case labelMultiMode
    case labelSecurity
    case labelSNI
    case labelFingerprint
    case labelPublicKey
    case labelShortId
    case labelSpiderX
    case labelAllowInsecure
    case labelPath
    case labelHost
    case btnCreateProfile
    case faqVpnQ
    case faqVpnA
    case faqDeepScanQ
    case faqDeepScanA
    
    // --- Routing (Маршрутизация) ---
        case routingMode
        case routeGlobal
        case routeDirect
        case routeRules
        case routingRulesHeader
        case routingReset
        
        // Описания режимов
        case routingDescGlobal
        case routingDescDirect
        case routingDescRules
        
        // --- Profile Editor (Дополнительные поля) ---
        case sectionGeneral
        case labelTransport
        case labelGrpcSettings
        case labelWsSettings
        case labelTlsSettings
        case labelRealitySettings
    
    // --- Localization Logic ---
    func localized(lang: AppLanguage) -> String {
        switch lang {
        case .russian:
            switch self {
            case .appTitle: return "KNOWER MANAGER"
            case .settingsTitle: return "Настройки"
            case .settingsGeneral: return "Общие"
            case .settingsAppearance: return "Внешний вид"
            case .launchAtLogin: return "Запускать при входе"
            case .launchAtLoginDesc: return "Автоматически запускать приложение при старте системы."
                
            case .vpnTitle: return "VPN"
            case .vpnProfilesLoaded: return "профилей загружено"
            case .vpnConnected: return "Подключено"
            case .vpnImportClipboard: return "Из буфера обмена"
            case .vpnImportFile: return "Из файла (.txt)"
            case .vpnDeleteAll: return "Удалить все профили"
            case .vpnPingAll: return "Пинг всех"
            case .vpnSearchPlaceholder: return "Поиск (vless, reality, us)..."
            case .vpnNoProfiles: return "Нет профилей"
            case .btnConnect: return "Подключить"
            case .btnDisconnect: return "Отключить"
            case .vpnImportUrl: return "Из ссылки (Subscription)"
            case .vpnRemoveDead: return "Удалить недоступные"
            case .vpnEnterUrlTitle: return "Введите ссылку подписки"
            case .vpnEnterUrlPlaceholder: return "https://example.com/sub..."
            case .vpnSortByPing: return "Сортировать по пингу"
            case .checkHTTP: return "Проверка"
            case .vpnOpenDataFolder: return "Открыть папку данных"
            case .vpnDeepScan: return "Проверить Топ-20"
            case .vpnStopScan: return "Остановить проверку"
            case .vpnImporting: return "Импорт"
            case .vpnDeepScanningTitle: return "Глубокая проверка..."
            case .vpnDeepScanningSubtitle: return "Тестируем кандидатов через"
            case .vpnCheckAll: return "Проверить ВСЕ"
            case .contextDelete: return "Удалить"
            case .contextConnect: return "Подключить"
            case .contextDisconnect: return "Отключить"
            case .contextFavorite: return "В избранное"
            case .contextUnfavorite: return "Убрать из избранного"
            case .vpnLatencyDead: return "МЕРТВ"
            case .contextPing: return "Пинг (TCP)"
            case .btnPingSelected: return "Пинг выбранных"
            case .contextEdit: return "Редактировать"
            case .editTitle: return "Редактирование профиля"
            case .labelName: return "Название"
            case .labelServer: return "Адрес (IP/Domain)"
            case .labelPort: return "Порт"
            case .labelUUID: return "UUID / Пароль"
            case .labelMethod: return "Метод / Security"
            case .labelProtocol: return "Протокол"
            case .labelNetwork: return "Сеть (Transport)"
            case .labelFlow: return "Flow (Vision)"
            case .labelEncryption: return "Шифрование"
            case .labelServiceName: return "Service Name"
            case .labelMultiMode: return "Multi Mode"
            case .labelSecurity: return "Безопасность (TLS)"
            case .labelSNI: return "SNI (Домен)"
            case .labelFingerprint: return "uTLS (Fingerprint)"
            case .labelPublicKey: return "Public Key"
            case .labelShortId: return "Short ID"
            case .labelSpiderX: return "SpiderX"
            case .labelAllowInsecure: return "Разрешить небезопасные (Insecure)"
            case .labelPath: return "Путь (Path)"
            case .labelHost: return "Хост (Host)"
            case .btnCreateProfile: return "Создать вручную"
            case .routingMode: return "Режим работы"
            case .routeGlobal: return "Глобальный"
            case .routeDirect: return "Напрямую"
            case .routeRules: return "По правилам"
            case .routingRulesHeader: return "Правила (Приоритет сверху вниз)"
            case .routingReset: return "Сбросить по умолчанию"
                        
            case .routingDescGlobal: return "Весь трафик принудительно идет через прокси."
            case .routingDescDirect: return "Весь трафик идет напрямую, минуя VPN."
            case .routingDescRules: return "Умный обход на основе доменов, IP и геолокации."
                        
            // --- Profile Editor ---
            case .sectionGeneral: return "Основное"
            case .labelTransport: return "Транспорт и Сеть"
            case .labelGrpcSettings: return "Настройки gRPC"
            case .labelWsSettings: return "Настройки WebSocket"
            case .labelTlsSettings: return "Настройки TLS"
            case .labelRealitySettings: return "Настройки Reality"
                
            case .routingModeExclude: return "Исключения"
            case .urlPlaceholder: return "Ссылка на список (https://...)"
            case .btnDownload: return "Скачать"
            case .downloadSuccess: return "Успешно загружено доменов:"
            case .downloadError: return "Ошибка загрузки"
                
            case .btnImport: return "Импорт"
            case .routingGlobalDesc: return "Весь трафик маршрутизируется глобально.\nХост-лист игнорируется."
                        
            case .importMessage: return "Выберите файл со списком доменов (.txt)"
            case .exportMessage: return "Сохранить список доменов"
                        
            case .logPacServer: return "📄 PAC Сервер запущен по адресу"
            case .logFwUpdated: return "Правила фаервола обновлены."
            case .logGatewayBlocked: return "🌐 Шлюз: UDP заблокирован (кроме DNS). Приложения переведены на TCP."
                        
            case .statusStoppedKS: return "ОСТАНОВЛЕНО (KILL SWITCH АКТИВЕН)"
                        
            case .passIncorrect: return "Неверный пароль. Попробуйте еще раз."
            case .passCancelled: return "Ввод пароля отменен"
            case .btnOK: return "OK"
                
            case .fixYtTitle: return "YouTube Fix"
            case .fixDsTitle: return "Discord Fix"
            case .gatewayTitle: return "Wi-Fi Шлюз"
            
            // --- Password ---
            case .passTitle: return "Требуются права администратора"
            case .passDesc: return "Введите пароль пользователя macOS для настройки сети."
            case .passPlaceholder: return "Пароль"
            case .passRemember: return "Запомнить пароль"
            case .passForget: return "Забыть сохраненный пароль"
                
            // 1. WARP
            case .faqWarpQ: return "Что умеет WARP Генератор?"
            case .faqWarpA: return "Создает личные конфиги (WireGuard/Amnezia) через Cloudflare. Сканер ищет «чистые» IP с низким пингом для стабильного соединения."
                                        
            // 2. VPN (Xray) — НОВОЕ
            case .faqVpnQ: return "Какие протоколы поддерживает VPN?"
            case .faqVpnA: return "VLESS (Reality, Vision), VMess, Trojan и Shadowsocks. Поддерживаются: gRPC, uTLS, SpiderX, а также ручное создание и редактирование профилей."
                            
            case .faqDeepScanQ: return "Что такое Turbo Deep Scan?"
            case .faqDeepScanA: return "Мощный сканер прокси. Проверяет тысячи серверов в 24 потока, автоматически находит живые (Alive), сортирует по скорости и удаляет мертвые."

            // 3. Инструменты
            case .faqToolsQ: return "Какие есть Инструменты?"
            case .faqToolsA: return "Тест скорости, Монитор трафика, Редактор хост-листа с пресетами, Сброс DNS и полная диагностика сети."
                                        
            // 4. Сканер (OCR) и AI
            case .faqOcrQ: return "Для чего нужен Сканер (OCR)?"
            case .faqOcrA: return "Мгновенно распознает текст с любой области экрана (даже из видео). Удобно для перевода ошибок или копирования защищенного текста."

            case .faqAiQ: return "Как работает AI в сканере?"
            case .faqAiA: return "AI не просто читает текст, но может перевести его, исправить грамматику, изменить стиль или выделить главную мысль (Summary)."
                                
            // 5. Bypass (Обход)
            case .faqWandQ: return "Что делает «Волшебная палочка»?"
            case .faqWandA: return "Это Auto Check. Приложение тестирует стратегии обхода (Split, Fake, Disorder) и само включает самую быструю для вашей сети."
                                            
            case .faqRouteQ: return "Что означают иконки Планета/Список?"
            case .faqRouteA: return "Режим маршрутизации:\n🌍 Планета — Обход DPI для всего трафика.\n📋 Список — Обход только для доменов из вашего Хост-листа."
                                            
            case .faqFixQ: return "Зачем нужны быстрые фиксы?"
            case .faqFixA: return "YouTube Fix блокирует QUIC (лечит бесконечную загрузку). Discord Fix исправляет проблемы с голосовой связью."
                                            
            // 6. Разное
            case .faqGatewayQ: return "Как работает Wi-Fi Gateway?"
            case .faqGatewayA: return "Раздает VPN/Обход на другие устройства (iPhone, TV, консоли). Требует включения «Общий интернет» в настройках macOS."
                                            
            case .faqKwQ: return "Что такое KnowerWatch?"
            case .faqKwA: return "Система авто-лечения. Следит за соединением в фоне и автоматически перезапускает защиту при сбоях или смене сети."
                
            case .statusProtected: return "ЗАЩИЩЕНО"
            case .statusDisconnected: return "ОТКЛЮЧЕНО"
                
            case .scanResults: return "Результаты"
            case .btnUse: return "Выбрать"
                
            case .gatewayActive: return "ШЛЮЗ АКТИВЕН"
            case .gatewayWaiting: return "Ожидание сети..."
            case .gatewayEnableHint: return "Включите 'Общий интернет' в настройках"
            case .btnOpenSettings: return "Настройки"
                
            case .previewLabel: return "Предпросмотр"
            case .previewClose: return "Закрыть предпросмотр"
            case .btnRefresh: return "Обновить всё"
            case .btnCopyImage: return "Копировать изображение"
            case .btnSaveImage: return "Сохранить изображение"
            case .warpFieldEndpoint: return "Кастомный эндпоинт (IP:Port)"
            case .warpFieldLicense: return "Лицензионный ключ"
            case .sshPassPlaceholder: return "Пароль"
            
            // --- NEW TRANSLATIONS ---
            case .diagTitle: return "Диагностика соединения"
            case .diagCheckBtn: return "Проверить"
            case .diagPlaceholder: return "example.com"
            case .diagSuccess: return "Доступ есть (200 OK)"
            case .diagFail: return "Недоступно / Ошибка"
            case .flushDnsBtn: return "Сброс DNS кэша"
            case .flushDnsSuccess: return "Кэш очищен!"
            case .presetsTitle: return "Пресеты"
            case .presetSocials: return "Соцсети"
            case .presetMedia: return "Медиа"
            case .presetNews: return "Новости"
            case .builderTitle: return "Конструктор стратегии"
            case .builderSplit: return "Split (Разделение)"
            case .builderDisorder: return "Disorder (Перемешивание)"
            case .builderFake: return "Fake (Фейк-пакеты)"
            case .builderTtl: return "TTL (Время жизни)"
            case .menuQuitShort: return "Выход"
            case .menuOpenShort: return "Открыть"
            case .killSwitchTitle: return "Kill Switch"
            case .killSwitchDesc: return "Блокировать интернет, если защита отключена."
                
            // --- KnowerWatch (RU) ---
            case .kwTitle: return "KnowerWatch (Авто-лечение)"
            case .kwDesc: return "Автоматически следит за соединением и подбирает рабочую стратегию при сбоях."
            case .kwNotificationTitle: return "KnowerWatch"
            case .kwRestoredBody: return "Интернет восстановлен: "
            case .kwSearchingStatus: return "KnowerWatch: Поиск решения..."
                
            // --- Tabs ---
            case .tabBypass: return "Обход"
            case .tabWarp: return "Warp"
            case .tabScanner: return "Сканер"
            case .toolsTitle, .tabTools: return "Инструменты" // Reusing toolsTitle logic or explicit
                            
            // --- Mini Menu ---
            case .mmOn: return "ВКЛ"
            case .mmOff: return "ВЫКЛ"
            case .mmSecureOff: return "ЗАЩИТА ОТКЛ"
            case .mmScanShort: return "Скан"
            case .mmDnsShort: return "DNS"
            case .mmSettingsShort: return "Настр."
            case .mmCopied: return "Лог скопирован"
                            
            // --- Warp Rules ---
            case .rulePorno: return "Порно (XXX)"
            case .ruleDiscord: return "Discord"
            case .ruleYoutube: return "YouTube"
            case .ruleSocials: return "Соцсети"
            case .ruleTorrent: return "Торренты"
            case .ruleTools: return "Инструменты (Dev)"
            case .ruleMusic: return "Музыка"
                            
            // --- Tools UI ---
            case .toolsNoMonitors: return "Нет активных мониторов"
            case .toolsAddTargetPlh: return "Добавить домен (google.com)"
            case .pingGoogle: return "Google"
            case .pingCloudflare: return "Cloudflare"
                            
            // --- Scanner UI ---
            case .ocrLabelImage: return "Изображение"
            case .ocrCharsCount: return "симв."
            case .ocrHelpClearAll: return "Удалить все"
            case .ocrHelpCloseImage: return "Закрыть изображение"
                            
            // --- Warp Status ---
            case .warpProxyAuto: return "Прокси: Авто"
            case .warpProxyDirect: return "Напрямую (Без прокси)"
              
            // --- OCR UI ---
            case .ocrTitle: return "OCR И СКАНЕР"
            case .ocrStart: return "Начать"
            case .ocrArea: return "Область"
            case .ocrScreen: return "Экран"
            case .ocrClipboard: return "Буфер"
            case .ocrLang: return "Язык"
            case .ocrHistory: return "ИСТОРИЯ"
            case .ocrResult: return "РЕЗУЛЬТАТ"
            case .ocrAI: return "AI Обработка"
            case .ocrAISettings: return "Настройки AI"
            case .ocrCopy: return "Копировать"
            case .ocrClear: return "Очистить"
            case .aiEnable: return "Включить AI"
            case .aiProvider: return "Провайдер"
            case .aiApiKey: return "API Ключ"
            case .aiModel: return "Модель"
                
            // --- OCR Statuses ---
            case .ocrStatusReady: return "Готов к работе"
            case .ocrCapturing: return "Захват..."
            case .ocrCancel: return "Отменено или пусто"
            case .ocrRecognizing: return "Распознавание..."
            case .ocrDone: return "Готово"
            case .ocrAIDisabled: return "AI отключен в настройках"
            case .ocrAIProcessing: return "AI обрабатывает..."
            case .ocrAIDone: return "AI завершил работу"
            case .ocrAIErrorPrefix: return "Ошибка AI: "
            case .ocrCopied: return "Текст скопирован"
            case .ocrCleared: return "Очищено"
            case .ocrHistoryLoaded: return "Загружено из истории"
            case .ocrSaveTitle: return "Сохранить текст"
            case .ocrSaveImageTitle: return "Сохранить изображение"
            case .ocrSaveError: return "Ошибка сохранения"
                
            // --- Screen Capture Permissions ---
            case .scPermTitle: return "Разрешение на захват экрана"
            case .scPermOpenSettings: return "Открыть настройки"
            case .scPermLater: return "Позже"
            case .scErrPermission: return "Необходимо предоставить разрешение на захват экрана"
            case .scErrFailed: return "Не удалось захватить экран"
            case .scErrCancelled: return "Захват отменен"
            
            // --- Languages ---
            case .langRu: return "Русский"
            case .langEn: return "English"
            case .langDe: return "Deutsch"
            case .langFr: return "Français"
            case .langEs: return "Español"
            
            // --- AI Operations ---
            case .aiOpRewrite: return "Переписать"
            case .aiOpImprove: return "Улучшить"
            case .aiOpSummarize: return "Сократить"
            case .aiOpTranslate: return "Перевести (EN)"
            case .aiOpGrammar: return "Грамматика"
            case .aiOpExpand: return "Дополнить"
            case .aiOpFormal: return "Официально"
            case .aiOpInformal: return "Неформально"
            case .aiOpTranslateRu: return "Перевести (RU)"
            
            // --- AI Prompts ---
            case .aiPromptRewrite: return "Перепиши этот текст другими словами:"
            case .aiPromptImprove: return "Улучши стиль и читаемость этого текста:"
            case .aiPromptSummarize: return "Кратко изложи суть этого текста:"
            case .aiPromptTranslate: return "Переведи этот текст на английский:"
            case .aiPromptGrammar: return "Исправь грамматические и пунктуационные ошибки:"
            case .aiPromptExpand: return "Дополни этот текст деталями:"
            case .aiPromptFormal: return "Перепиши этот текст в официальном стиле:"
            case .aiPromptInformal: return "Перепиши этот текст в разговорном стиле:"
            case .aiPromptTranslateRu: return "Переведи этот текст на русский язык:"
            
            // --- AI Errors ---
            case .aiErrConfig: return "Ошибка настройки:"
            case .aiErrEmpty: return "Текст пуст"
            case .aiErrNetwork: return "Ошибка сети:"
            case .aiErrApi: return "Ошибка API:"
            
            // --- Other Keys ---
            case .fixesTitle: return "Быстрые фиксы"
            case .fixYoutube: return "Fix YouTube (Block QUIC)"
            case .fixDiscord: return "Fix Discord (Voice UDP)"
            case .dashboardPing: return "Пинг"
            case .dashboardGraph: return "Сетевая активность"
            case .statusWaiting: return "Требуется файл tpws"
            case .statusReady: return "Готов к запуску"
            case .statusMissing: return "Файл не найден"
            case .statusDownloading: return "Скачивание..."
            case .statusError: return "Ошибка"
            case .statusStarting: return "Запуск..."
            case .statusActive: return "АКТИВЕН"
            case .statusActiveShort: return "Активен"
            case .statusStopped: return "Остановлено"
            case .statusProtectionActive: return "Защита активна"
            case .checking: return "Идет подбор..."
            case .autoFound: return "Найдено"
            case .notFound: return "Не найдено"
            
            case .hideDockTitle: return "Скрыть в Dock"
            case .hideDockDesc: return "Показывать только в строке меню."
            case .automationTitle: return "Автоматизация"
            case .notificationsTitle: return "Уведомления"
            case .notificationsDesc: return "Сообщать об изменении статуса."
            
            case .toolsSpeedTest: return "Тест"
            case .toolsHostlist: return "Редактор списка"
            case .toolsTraffic: return "Монитор трафика"
            
            case .speedDownload: return "Скачивание"
            case .speedRun: return "Запустить тест"
            case .speedTesting: return "Тестирование..."
            
            case .hostPlaceholder: return "domain.com"
            case .hostAdd: return "Добавить"
            case .hostLoadPopular: return "Загрузить популярные"
            case .hostSave: return "Сохранить список"
            
            case .logMonitor: return "Живой мониторинг трафика"
            case .logClear: return "Очистить"
            case .logTime: return "Время"
            case .logDomain: return "Домен"
            case .logStatus: return "Статус"
            
            case .proxyScan: return "Сканирование..."
            case .proxyDirect: return "Напрямую (Без прокси)"
            case .proxyFound: return "Прокси:"
            case .statusGenerating: return "Генерация..."
            case .statusSuccess: return "Успешно!"
            case .statusSaved: return "Сохранено в файл"
            case .statusCopied: return "Скопировано!"
            case .errorPrefix: return "Ошибка: "
            
            case .btnAutoInstall: return "Установить автоматически"
            case .btnManualInstall: return "Выбрать файл вручную"
            case .btnAutoCheck: return "Авто-подбор (Auto Check)"
            case .btnStart: return "Запустить"
            case .btnStop: return "Остановить"
            case .btnCopy: return "Копировать"
            case .btnScan: return "Сканировать"
            case .btnGenerate: return "СГЕНЕРИРОВАТЬ КЛЮЧ"
            case .btnSaveFile: return "Сохранить"
            case .btnDone: return "Готово"
            case .btnCancel: return "Отмена"
            case .btnSave: return "Сохранить"
            
            case .titleStrategy: return "Стратегия"
            case .titleDNS: return "DNS Сервер"
            case .titleLog: return "Терминал / Лог"
            case .setupTitle: return "Компоненты не найдены"
            case .setupDesc: return "Для работы программы требуется ядро tpws."
            
            case .routingTitle: return "Правила маршрутизации"
            case .routingDesc: return "Выберите режим работы обхода."
            case .routingModeGlobal: return "Весь трафик"
            case .routingModeList: return "Список"
            case .routingAddPlaceholder: return "example.com"
            case .routingAddBtn: return "Добавить"
            case .routingListHeader: return "Список доменов"
            
            case .stratSplit2: return "1. Split 2 (Стандарт)"
            case .stratDisorder: return "2. Disorder (Мощный)"
            case .stratFake: return "3. Fake (Оч. мощный)"
            case .stratOOB: return "4. OOB (Альтернатива)"
            case .stratSplit1: return "5. Split 1 (Мягкий)"
            case .stratFlowseal: return "6. Flowseal"
            case .stratTlsRec: return "7. TLS Record Split"
            case .stratseqOverl: return "8. Sequence Overlap (Heavy)"
            case .stratmultiDisorder: return "9. Multi Disorder"
            case .stratAuto: return "10. Auto (Лучшая)"
            case .stratCustom: return "11. Своя (Custom)"
            case .stratCustomPlaceholder: return "--disorder --split-pos=2 (Ваши аргументы)"
            
            case .logScanStarted: return "=== ЗАПУСК ПОЛНОГО СКАНА ==="
            case .logTargets: return "Целей"
            case .logTest: return "Тест"
            case .logResult: return "Результат"
            case .logWinner: return "ПОБЕДИТЕЛЬ"
            case .logAccessApplied: return "Доступность"
            case .logNoStrategy: return "Рабочая стратегия не найдена."
            case .logProxyStarted: return "Прокси запущен. DNS в туннеле."
            case .logInstallSuccess: return "Установка завершена успешно."
            case .logBuildError: return "Ошибка сборки/установки:"
            
            case .warpTitle: return "Генератор WARP"
            case .warpFormat: return "Формат:"
            case .warpGenSettings: return "Настройки генерации"
            
            case .warpMethod: return "Метод генерации"
            case .methodLocal: return "Локально"
            case .methodSSH: return "Через удаленный сервер (SSH)"
            case .sshHost: return "Хост (IP)"
            case .sshUser: return "Пользователь"
            case .sshPort: return "Порт"
            case .sshPass: return "Пароль / Путь к ключу"
            case .warpParams: return "Параметры AmneziaWG"
            case .warpRouting: return "Правила маршрутизации"
            
            case .ipScanTitle: return "Сканер IP Cloudflare"
            case .ipScanBestIP: return "Лучший найденный IP:"
            case .ipScanStart: return "Начать сканирование"
            case .ipScanButton: return "Сканер"
            case .endpointAuto: return "Эндпоинт (Авто)"
            case .endpointScanHelp: return "Найти быстрые IP Cloudflare"
            case .qrFailedTitle: return "Ошибка QR кода"
            case .qrFailedDesc: return "Конфиг слишком большой или некорректный."
            case .qrScanImport: return "Сканируйте для импорта"
            case .btnShare: return "Поделиться"
            case .btnSaved: return "Сохранено"
            
            case .qrTitle: return "QR Код Конфига"
            case .qrNotGenerated: return "QR код не сгенерирован"
            case .qrScanHint: return "Отсканируйте для импорта"
            
            case .aboutPowered: return "Ядро: zapret (bol-van) | Сеть: Cloudflare & Google"
            case .aboutVersion: return "Версия 3.0 Ultimate"
            case .aboutCopyright: return "© 2025 KnowerLife. Open Source."
            
            case .menuStatusLabel: return "Статус:"
            case .menuLanguage: return "Язык"
            case .menuTheme: return "Тема"
            case .menuAbout: return "О программе"
            case .menuOpen: return "Открыть окно"
            case .menuQuit: return "Выход"
            
            case .hostSaveMessage: return "Выберите место для сохранения списка доменов."
            }
            
        case .english:
            switch self {
            case .appTitle: return "KNOWER MANAGER"
            
            case .settingsTitle: return "Settings"
            case .settingsGeneral: return "General"
            case .settingsAppearance: return "Appearance"
            case .launchAtLogin: return "Launch at Login"
            case .launchAtLoginDesc: return "Automatically start the app when you log in."
                
            case .vpnTitle: return "VPN"
            case .vpnProfilesLoaded: return "profiles loaded"
            case .vpnConnected: return "Connected"
            case .vpnImportClipboard: return "From Clipboard"
            case .vpnImportFile: return "From File (.txt)"
            case .vpnDeleteAll: return "Delete All Profiles"
            case .vpnPingAll: return "Ping All"
            case .vpnSearchPlaceholder: return "Search (e.g. vless, reality, us)..."
            case .vpnNoProfiles: return "No profiles"
            case .btnConnect: return "Connect"
            case .btnDisconnect: return "Disconnect"
            case .vpnImportUrl: return "From URL (Subscription)"
            case .vpnRemoveDead: return "Remove Unreachable"
            case .vpnEnterUrlTitle: return "Enter Subscription URL"
            case .vpnEnterUrlPlaceholder: return "https://example.com/sub..."
            case .vpnSortByPing: return "Sort by Ping"
            case .checkHTTP: return "Check HTTP"
            case .vpnOpenDataFolder: return "Open Data Folder"
            case .vpnDeepScan: return "Deep Scan Top 20"
            case .vpnStopScan: return "Stop Deep Scan"
            case .vpnImporting: return "Importing profiles..."
            case .vpnDeepScanningTitle: return "Deep Scanning..."
            case .vpnDeepScanningSubtitle: return "Testing top candidates"
            case .vpnCheckAll: return "Check ALL"
            case .contextDelete: return "Delete"
            case .contextConnect: return "Connect"
            case .contextDisconnect: return "Disconnect"
            case .contextFavorite: return "Add to Favorites"
            case .contextUnfavorite: return "Remove from Favorites"
            case .vpnLatencyDead: return "DEAD"
            case .contextPing: return "Ping (TCP)"
            case .btnPingSelected: return "Ping Selected"
            case .contextEdit: return "Edit"
            case .editTitle: return "Edit Profile"
            case .labelName: return "Name"
            case .labelServer: return "Address (IP/Domain)"
            case .labelPort: return "Port"
            case .labelUUID: return "UUID / Password"
            case .labelMethod: return "Method / Security"
            case .labelProtocol: return "Protocol"
            case .labelNetwork: return "Network"
            case .labelFlow: return "Flow"
            case .labelEncryption: return "Encryption"
            case .labelServiceName: return "Service Name"
            case .labelMultiMode: return "Multi Mode"
            case .labelSecurity: return "Security"
            case .labelSNI: return "SNI"
            case .labelFingerprint: return "uTLS Fingerprint"
            case .labelPublicKey: return "Public Key"
            case .labelShortId: return "Short ID"
            case .labelSpiderX: return "SpiderX"
            case .labelAllowInsecure: return "Allow Insecure"
            case .labelPath: return "Path"
            case .labelHost: return "Host"
            case .btnCreateProfile: return "Create Manually"
            case .routingMode: return "Routing Mode"
            case .routeGlobal: return "Global (Proxy All)"
            case .routeDirect: return "Direct (No VPN)"
            case .routeRules: return "Rule-Based"
            case .routingRulesHeader: return "Rules (Priority: Top to Bottom)"
            case .routingReset: return "Reset to Defaults"
                        
            case .routingDescGlobal: return "All traffic goes through the Proxy."
            case .routingDescDirect: return "All traffic goes Direct (Bypass VPN)."
            case .routingDescRules: return "Smart routing based on domain, IP, and geo."
                        
            // --- Profile Editor ---
            case .sectionGeneral: return "General"
            case .labelTransport: return "Transport & Network"
            case .labelGrpcSettings: return "gRPC Settings"
            case .labelWsSettings: return "WebSocket Settings"
            case .labelTlsSettings: return "TLS Settings"
            case .labelRealitySettings: return "Reality Settings"
                
            case .routingModeExclude: return "Exclude List"
            case .urlPlaceholder: return "List URL (https://...)"
            case .btnDownload: return "Download"
            case .downloadSuccess: return "Successfully loaded domains:"
            case .downloadError: return "Download error"
                
            case .btnImport: return "Import"
            case .routingGlobalDesc: return "Traffic is routed globally.\nHostlist is ignored."
                        
            case .importMessage: return "Select domain list file (.txt)"
            case .exportMessage: return "Save domain list"
                        
            case .logPacServer: return "📄 PAC Server running at"
            case .logFwUpdated: return "Firewall rules updated."
            case .logGatewayBlocked: return "🌐 Gateway: UDP Blocked (Except DNS). Apps forced to TCP."
                        
            case .statusStoppedKS: return "STOPPED (KILL SWITCH ACTIVE)"
                        
            case .passIncorrect: return "Incorrect password. Try again."
            case .passCancelled: return "Password cancelled"
            case .btnOK: return "OK"
                
            case .fixYtTitle: return "YouTube Fix"
            case .fixDsTitle: return "Discord Fix"
            case .gatewayTitle: return "Wi-Fi Gateway"
            
            // --- Password ---
            case .passTitle: return "Administrator privileges required"
            case .passDesc: return "Enter your macOS user password to configure network."
            case .passPlaceholder: return "Password"
            case .passRemember: return "Remember password"
            case .passForget: return "Forget saved password"
                
            // 1. WARP
            case .faqWarpQ: return "What can WARP Generator do?"
            case .faqWarpA: return "Creates personal VPN configs (WireGuard/Amnezia) via Cloudflare. The scanner finds 'clean' IPs with low ping for a stable connection."
                                        
            // 2. VPN (Xray) — NEW
            case .faqVpnQ: return "Which protocols are supported?"
            case .faqVpnA: return "VLESS (Reality, Vision), VMess, Trojan, and Shadowsocks. Supports: gRPC, uTLS, SpiderX, as well as manual profile creation and editing."
                            
            case .faqDeepScanQ: return "What is Turbo Deep Scan?"
            case .faqDeepScanA: return "A powerful proxy scanner. Checks thousands of servers in 24 threads, automatically finds Alive ones, sorts by speed, and removes dead ones."

            // 3. Tools
            case .faqToolsQ: return "What Tools are available?"
            case .faqToolsA: return "Speed Test, Traffic Monitor, Host List Editor with presets, DNS Flush, and full Network Diagnostics."
                                        
            // 4. Scanner (OCR) and AI
            case .faqOcrQ: return "What is the Scanner (OCR) for?"
            case .faqOcrA: return "Instantly recognizes text from any screen area, even from video. Useful for translating errors or copying protected text."

            case .faqAiQ: return "How does AI work in the scanner?"
            case .faqAiA: return "AI doesn't just read text; it can translate, fix grammar, change style, or summarize the main point."
                                
            // 5. Bypass
            case .faqWandQ: return "What does the 'Magic Wand' do?"
            case .faqWandA: return "It's Auto Check. The app tests bypass strategies (Split, Fake, Disorder) and automatically enables the fastest one for your network."
                                            
            case .faqRouteQ: return "What do the Globe/List icons mean?"
            case .faqRouteA: return "Routing mode:\n🌍 Globe — Bypass DPI for all traffic.\n📋 List — Bypass only for domains in your Host List."
                                            
            case .faqFixQ: return "Why do I need Quick Fixes?"
            case .faqFixA: return "YouTube Fix blocks QUIC (fixes infinite loading). Discord Fix resolves voice chat issues."
                                            
            // 6. Misc
            case .faqGatewayQ: return "How does Wi-Fi Gateway work?"
            case .faqGatewayA: return "Shares VPN/Bypass with other devices (iPhone, TV, consoles). Requires 'Internet Sharing' enabled in macOS settings."
                                            
            case .faqKwQ: return "What is KnowerWatch?"
            case .faqKwA: return "Self-healing system. Monitors connection in the background and automatically restarts protection upon failures or network changes."
                
            case .statusProtected: return "PROTECTED"
            case .statusDisconnected: return "DISCONNECTED"
                
            case .scanResults: return "Results"
            case .btnUse: return "Use"
                
            case .gatewayActive: return "GATEWAY ACTIVE"
            case .gatewayWaiting: return "Waiting for network..."
            case .gatewayEnableHint: return "Enable 'Internet Sharing' in Settings"
            case .btnOpenSettings: return "Open Settings"
                
            case .previewLabel: return "Preview"
            case .previewClose: return "Close Preview"
            case .btnRefresh: return "Refresh All"
            case .btnCopyImage: return "Copy Image"
            case .btnSaveImage: return "Save Image"
            case .warpFieldEndpoint: return "Custom Endpoint"
            case .warpFieldLicense: return "License Key"
            case .sshPassPlaceholder: return "Password"
            
            // --- NEW TRANSLATIONS (EN) ---
            case .diagTitle: return "Connection Diagnostics"
            case .diagCheckBtn: return "Check"
            case .diagPlaceholder: return "example.com"
            case .diagSuccess: return "Available (200 OK)"
            case .diagFail: return "Unavailable / Error"
            case .flushDnsBtn: return "Flush DNS Cache"
            case .flushDnsSuccess: return "Cache Flushed!"
            case .presetsTitle: return "Presets"
            case .presetSocials: return "Socials"
            case .presetMedia: return "Media"
            case .presetNews: return "News"
            case .builderTitle: return "Strategy Builder"
            case .builderSplit: return "Split"
            case .builderDisorder: return "Disorder"
            case .builderFake: return "Fake"
            case .builderTtl: return "TTL"
            case .menuQuitShort: return "Quit"
            case .menuOpenShort: return "Open"
            case .killSwitchTitle: return "Kill Switch"
            case .killSwitchDesc: return "Block internet if protection is disabled."
                
            // --- KnowerWatch (EN) ---
            case .kwTitle: return "KnowerWatch (Auto-Heal)"
            case .kwDesc: return "Automatically monitors connection health and finds working strategy if internet fails."
            case .kwNotificationTitle: return "KnowerWatch"
            case .kwRestoredBody: return "Internet restored: "
            case .kwSearchingStatus: return "KnowerWatch: Finding solution..."
                
            // --- Tabs ---
            case .tabBypass: return "Bypass"
            case .tabWarp: return "Warp"
            case .tabScanner: return "Scanner"
            case .toolsTitle, .tabTools: return "Tools"
                            
            // --- Mini Menu ---
            case .mmOn: return "ON"
            case .mmOff: return "OFF"
            case .mmSecureOff: return "SECURE OFF"
            case .mmScanShort: return "Scan"
            case .mmDnsShort: return "DNS"
            case .mmSettingsShort: return "Settings"
            case .mmCopied: return "Log Copied"
                            
            // --- Warp Rules ---
            case .rulePorno: return "Porno (XXX)"
            case .ruleDiscord: return "Discord"
            case .ruleYoutube: return "YouTube"
            case .ruleSocials: return "Social Networks"
            case .ruleTorrent: return "Torrents"
            case .ruleTools: return "Tools"
            case .ruleMusic: return "Music"
                            
            // --- Tools UI ---
            case .toolsNoMonitors: return "No active monitors"
            case .toolsAddTargetPlh: return "Add domain (google.com)"
            case .pingGoogle: return "Google"
            case .pingCloudflare: return "Cloudflare"
                            
            // --- Scanner UI ---
            case .ocrLabelImage: return "Image"
            case .ocrCharsCount: return "chars"
            case .ocrHelpClearAll: return "Clear All"
            case .ocrHelpCloseImage: return "Close Image"
                            
            // --- Warp Status ---
            case .warpProxyAuto: return "Proxy: Auto"
            case .warpProxyDirect: return "Direct (No Proxy)"
              
            case .ocrTitle: return "OCR & SCANNER"
            case .ocrStart: return "Start"
            case .ocrArea: return "Area"
            case .ocrScreen: return "Screen"
            case .ocrClipboard: return "Clipboard"
            case .ocrLang: return "Language"
            case .ocrHistory: return "HISTORY"
            case .ocrResult: return "RESULT"
            case .ocrAI: return "AI Magic"
            case .ocrAISettings: return "AI Settings"
            case .ocrCopy: return "Copy"
            case .ocrClear: return "Clear"
            case .aiEnable: return "Enable AI"
            case .aiProvider: return "Provider"
            case .aiApiKey: return "API Key"
            case .aiModel: return "Model"
                
            // --- OCR Statuses ---
            case .ocrStatusReady: return "Ready"
            case .ocrCapturing: return "Capturing..."
            case .ocrCancel: return "Cancelled or empty"
            case .ocrRecognizing: return "Recognizing..."
            case .ocrDone: return "Done"
            case .ocrAIDisabled: return "AI is disabled in settings"
            case .ocrAIProcessing: return "AI processing..."
            case .ocrAIDone: return "AI finished"
            case .ocrAIErrorPrefix: return "AI Error: "
            case .ocrCopied: return "Text copied"
            case .ocrCleared: return "Cleared"
            case .ocrHistoryLoaded: return "Loaded from history"
            case .ocrSaveTitle: return "Save Text"
            case .ocrSaveImageTitle: return "Save Scan Image"
            case .ocrSaveError: return "Save Error"
                
            // --- Screen Capture Permissions ---
            case .scPermTitle: return "Screen Recording Permission"
            case .scPermOpenSettings: return "Open Settings"
            case .scPermLater: return "Later"
            case .scErrPermission: return "Screen recording permission is required"
            case .scErrFailed: return "Failed to capture screen"
            case .scErrCancelled: return "Capture cancelled"
            
            // --- Languages ---
            case .langRu: return "Russian"
            case .langEn: return "English"
            case .langDe: return "German"
            case .langFr: return "French"
            case .langEs: return "Spanish"
            
            // --- AI Operations ---
            case .aiOpRewrite: return "Rewrite"
            case .aiOpImprove: return "Improve"
            case .aiOpSummarize: return "Summarize"
            case .aiOpTranslate: return "Translate (EN)"
            case .aiOpGrammar: return "Fix Grammar"
            case .aiOpExpand: return "Expand"
            case .aiOpFormal: return "Formal"
            case .aiOpInformal: return "Informal"
            case .aiOpTranslateRu: return "Translate (RU)"
            
            // --- AI Prompts ---
            case .aiPromptRewrite: return "Rewrite this text using different words:"
            case .aiPromptImprove: return "Improve the style and readability of this text:"
            case .aiPromptSummarize: return "Summarize this text:"
            case .aiPromptTranslate: return "Translate this text to English:"
            case .aiPromptGrammar: return "Fix grammar and punctuation errors:"
            case .aiPromptExpand: return "Expand this text with details:"
            case .aiPromptFormal: return "Rewrite this text in a formal style:"
            case .aiPromptInformal: return "Rewrite this text in a casual style:"
            case .aiPromptTranslateRu: return "Translate this text to Russian:"
            
            // --- AI Errors ---
            case .aiErrConfig: return "Configuration error:"
            case .aiErrEmpty: return "Text is empty"
            case .aiErrNetwork: return "Network error:"
            case .aiErrApi: return "API error:"
            
            // --- Other Keys ---
            case .fixesTitle: return "Quick Fixes"
            case .fixYoutube: return "Fix YouTube (Block QUIC)"
            case .fixDiscord: return "Fix Discord (Voice UDP)"
            case .dashboardPing: return "Ping"
            case .dashboardGraph: return "Network Activity"
            case .statusWaiting: return "tpws file required"
            case .statusReady: return "Ready to start"
            case .statusMissing: return "File not found"
            case .statusDownloading: return "Downloading..."
            case .statusError: return "Error"
            case .statusStarting: return "Starting..."
            case .statusActive: return "ACTIVE"
            case .statusActiveShort: return "Active"
            case .statusStopped: return "Stopped"
            case .statusProtectionActive: return "Protection Active"
            case .checking: return "Checking..."
            case .autoFound: return "Found"
            case .notFound: return "Not Found"
            
            case .hideDockTitle: return "Hide in Dock"
            case .hideDockDesc: return "Show app only in Menu Bar."
            case .automationTitle: return "Automation"
            case .notificationsTitle: return "Notifications"
            case .notificationsDesc: return "Notify when status changes."
            
            case .toolsSpeedTest: return "Speed Test"
            case .toolsHostlist: return "Hostlist Editor"
            case .toolsTraffic: return "Traffic Log"
            
            case .speedDownload: return "Download"
            case .speedRun: return "Run Speed Test"
            case .speedTesting: return "Testing..."
            
            case .hostPlaceholder: return "domain.com"
            case .hostAdd: return "Add"
            case .hostLoadPopular: return "Load Popular"
            case .hostSave: return "Save List"
            
            case .logMonitor: return "Live Traffic Monitor"
            case .logClear: return "Clear"
            case .logTime: return "Time"
            case .logDomain: return "Domain"
            case .logStatus: return "Status"
            
            case .proxyScan: return "Scanning..."
            case .proxyDirect: return "Direct (No Proxy)"
            case .proxyFound: return "Proxy:"
            case .statusGenerating: return "Generating..."
            case .statusSuccess: return "Success!"
            case .statusSaved: return "Saved to file"
            case .statusCopied: return "Copied!"
            case .errorPrefix: return "Error: "
            
            case .btnAutoInstall: return "Install Automatically"
            case .btnManualInstall: return "Select File Manually"
            case .btnAutoCheck: return "Auto Check Strategy"
            case .btnStart: return "ACTIVATE"
            case .btnStop: return "STOP SERVICE"
            case .btnCopy: return "Copy"
            case .btnScan: return "Scan Proxy"
            case .btnGenerate: return "GENERATE KEY"
            case .btnSaveFile: return "Save File"
            case .btnDone: return "Done"
            case .btnCancel: return "Cancel"
            case .btnSave: return "Save"
            
            case .titleStrategy: return "Bypass Strategy"
            case .titleDNS: return "DNS Server"
            case .titleLog: return "Terminal Output"
            case .setupTitle: return "Components Missing"
            case .setupDesc: return "The app requires the tpws core to work."
            
            case .routingTitle: return "Routing Rules"
            case .routingDesc: return "Choose bypass mode."
            case .routingModeGlobal: return "Global"
            case .routingModeList: return "List"
            case .routingAddPlaceholder: return "example.com"
            case .routingAddBtn: return "Add"
            case .routingListHeader: return "Domain List"
            
            case .stratSplit2: return "1. Split 2 (Standard)"
            case .stratDisorder: return "2. Disorder (Powerful)"
            case .stratFake: return "3. Fake (Very Powerful)"
            case .stratOOB: return "4. OOB (Alternative)"
            case .stratSplit1: return "5. Split 1 (Soft)"
            case .stratFlowseal: return "6. Flowseal"
            case .stratTlsRec: return "7. TLS Record Split"
            case .stratseqOverl: return "8. Sequence Overlap (Heavy)"
            case .stratmultiDisorder: return "9. Multi Disorder"
            case .stratAuto: return "10. Auto (Best Found)"
            case .stratCustom: return "11. Custom"
            case .stratCustomPlaceholder: return "--disorder --split-pos=2 (Your args)"
            
            case .logScanStarted: return "=== SCAN STARTED ==="
            case .logTargets: return "Targets"
            case .logTest: return "Test"
            case .logResult: return "Result"
            case .logWinner: return "WINNER"
            case .logAccessApplied: return "Access"
            case .logNoStrategy: return "No working strategy found."
            case .logProxyStarted: return "Proxy started. DNS tunneled."
            case .logInstallSuccess: return "Installation completed successfully."
            case .logBuildError: return "Build/Install Error:"
            
            case .warpTitle: return "WARP Config Gen"
            case .warpFormat: return "Format:"
            case .warpGenSettings: return "Generation Settings"
            
            case .warpMethod: return "Generation Method"
            case .methodLocal: return "Local Device"
            case .methodSSH: return "Via SSH Server"
            case .sshHost: return "Host (IP)"
            case .sshUser: return "User"
            case .sshPort: return "Port"
            case .sshPass: return "Password / Key Path"
            case .warpParams: return "AmneziaWG Params"
            case .warpRouting: return "Routing Rules"
            
            case .ipScanTitle: return "Cloudflare IP Scanner"
            case .ipScanBestIP: return "Best IP found:"
            case .ipScanStart: return "Start Scan"
            case .ipScanButton: return "Scanner"
            case .endpointAuto: return "Endpoint (Auto)"
            case .endpointScanHelp: return "Scan Cloudflare IPs"
            case .qrFailedTitle: return "QR Code generation failed"
            case .qrFailedDesc: return "The config is too large or invalid."
            case .qrScanImport: return "Scan to import"
            case .btnShare: return "Share"
            case .btnSaved: return "Saved"
            
            case .qrTitle: return "Config QR Code"
            case .qrNotGenerated: return "QR Code not generated"
            case .qrScanHint: return "Scan to import config"
            
            case .aboutPowered: return "Core: zapret (bol-van) | Network: Cloudflare & Google"
            case .aboutVersion: return "Version 3.0 Ultimate"
            case .aboutCopyright: return "© 2025 KnowerLife. Open Source."
            
            case .menuStatusLabel: return "Status:"
            case .menuLanguage: return "Language"
            case .menuTheme: return "Theme"
            case .menuAbout: return "About"
            case .menuOpen: return "Open Window"
            case .menuQuit: return "Quit"
            
            case .hostSaveMessage: return "Choose where to save your domain list."
            }
        }
    }
}
