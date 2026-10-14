import Foundation

// MARK: - Ключи локализации
//
// Здесь только объявления ключей (без самих переводов).
// Строки переводов лежат рядом: LocalizationRU.swift и LocalizationEN.swift.

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
    
    // --- Statuses ---
    case statusCopied
    case errorPrefix
    
    // --- Tabs (TopBar) ---
    case tabOcr

        
    // --- Mini Menu ---
    case mmOn, mmOff, mmSecureOff
    case mmScanShort, mmDnsShort, mmSettingsShort
    case mmCopied
        
        
    // --- Tools UI ---
    case toolsNoMonitors, toolsAddTargetPlh
    case pingGoogle, pingCloudflare
        
    // --- Scanner UI Extra ---
    case ocrLabelImage, ocrCharsCount, ocrHelpClearAll, ocrHelpCloseImage
        
    
    // --- Buttons ---
    case btnAutoInstall, btnManualInstall, btnAutoCheck
    case btnStart, btnStop
    case btnDone, btnCancel, btnSave
    
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
    
    
    
    // --- QR Code ---
    case qrNotGenerated
    
    // --- About Window ---
    case aboutPowered, aboutVersion, aboutCopyright
    case aboutTagline, aboutIntro
    
    // --- Menu Bar ---
    case menuStatusLabel, menuLanguage, menuTheme, menuAbout, menuOpen, menuQuit
    
    case qrScanImport
    case btnShare
    
    // --- Tools ---
    case toolsTitle, toolsSpeedTest, toolsHostlist, toolsTraffic
    case speedDownload, speedRun, speedTesting
    case hostPlaceholder, hostAdd, hostLoadPopular, hostSave
    case logMonitor, logClear, logTime, logDomain, logStatus
    case logTitle, logShow, logHide, logCopy, logPath
    case toolsDNSTitle, toolsDNSDesc, toolsFlushDNS, toolsFlushDNSResult
    case toolsTrafficTitle, toolsTrafficDesc, toolsTrafficIn, toolsTrafficOut
    case toolsPingTitle, toolsPingDesc, toolsPingHost, toolsPingButton
    case toolsPortTitle, toolsPortDesc, toolsPortHost, toolsPortPort, toolsPortButton
    case toolsResult, toolsCopy
    
    // --- General Settings Extra ---
    case hideDockTitle, hideDockDesc
    case openWindowOnLaunchTitle, openWindowOnLaunchDesc
    case btnCheckUpdates, updateChecking, updateUpToDate, updateAvailable, updateCheckFailed
    
    // --- Automation Settings ---
    case automationTitle
    case notificationsTitle, notificationsDesc
    case hostSaveMessage
    
    // --- OCR Settings ---
    case ocrSettingsTitle
    case ocrGlobalHotkeyTitle, ocrGlobalHotkeyDesc
    case ocrHotkeyChange, ocrHotkeyChangeDesc, ocrHotkeyRecord, ocrHotkeyRecording, ocrHotkeyReset
    case ocrAutoCopyTitle, ocrAutoCopyDesc
    
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
    case aiTestConnection, aiTestSuccess, aiTemperature, aiMaxTokens, aiShowKey, aiHideKey, aiAdvanced
    
    // --- OCR: тонкая настройка распознавания ---
    case ocrAdvanced, ocrRecognition
    case ocrLevelAccurate, ocrLevelFast
    case ocrLanguageCorrection, ocrAutoDetect, ocrMinTextHeight
    case ocrCustomWords, ocrCustomWordsPlaceholder
    case ocrDetectBarcodes, ocrLanguages, ocrImageOrientation
    case ocrOrientationUp, ocrOrientationDown, ocrOrientationLeft, ocrOrientationRight
    
    // --- OCR: предобработка изображения ---
    case ocrEnhance, ocrEnhanceEnabled, ocrGrayscale, ocrContrast, ocrBrightness
    case ocrSharpness, ocrInvert, ocrBinarize, ocrBinarizeThreshold, ocrUpscale, ocrReset
    
    // --- OCR: импорт ---
    case ocrImport, ocrImportFiles, ocrImportPDF, ocrImportScannerTitle, ocrScannerHint
    case ocrScannerScan, ocrScannerOverview, ocrScannerClose
    case ocrImporting, ocrImportEmpty, ocrImportDone, ocrImportScanner
    case ocrImportHint, ocrCopyAllHint
    case ocrTextEdited, ocrResetText
    
    // --- OCR: экспорт ---
    case ocrExport, ocrExportTxt, ocrExportMarkdown, ocrExportJSON, ocrExportSearchablePDF
    case ocrExportDone, ocrExportError
    case ocrPreferEmbeddedPDF
    
    // --- OCR: озвучка ---
    case ocrSpeak, ocrStopSpeak, ocrPauseSpeak, ocrResumeSpeak, ocrTTSVoice, ocrTTSRate, ocrTTSSettings
    case ocrSpeechLanguage, ocrSpeechLangAuto
    case ocrTextLanguage, ocrRecognitionLanguage
    
    // --- OCR: штрих-коды и рамки ---
    case ocrBarcodes, ocrNoBarcodes, ocrShowBoxes, ocrDetectedLanguage, ocrConfidence
    
    // --- OCR: страницы ---
    case ocrPage, ocrPages, ocrRemovePage, ocrReRecognize, ocrRecognizeAll
    
    case ocrErrImage
    
    // --- OCR Statuses & Errors ---
    case ocrStatusReady, ocrCapturing, ocrCancel, ocrRecognizing, ocrDone
    case ocrAIDisabled, ocrAIProcessing, ocrAIDone, ocrAIErrorPrefix
    case ocrCopied, ocrCleared, ocrHistoryLoaded, ocrSaveTitle, ocrSaveError
    case ocrClearHistory
    case ocrSearchHistory, ocrSearchHistoryPlaceholder
    
    // --- Screen Capture Permissions ---
    case scPermTitle, scPermOpenSettings, scPermLater
    case scErrPermission, scErrFailed, scErrCancelled
    
    // --- New Features (Diagnostics, Presets, Builder) ---
    case diagTitle, diagCheckBtn, diagPlaceholder, diagSuccess, diagFail
    case flushDnsBtn, flushDnsSuccess
    case presetsTitle, presetSocials, presetMedia, presetNews
    case builderTitle, builderSplit, builderDisorder, builderFake, builderTtl
    case menuQuitShort, menuOpenShort
    
    // --- OCR Languages ---
    case langRu, langEn, langDe, langFr, langEs
    case langIt, langPt, langUk, langPl, langTr, langNl, langSv, langDa
    case langNo, langFi, langCs, langZhHans, langZhHant, langJa, langKo
    case langAr, langHe, langTh, langVi
    
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
    
    case statusProtected, statusDisconnected
    
    // --- Gateway Card ---
    case gatewayActive
    case gatewayWaiting, gatewayEnableHint
    case btnOpenSettings
    
    
    case faqWandQ, faqWandA
    case faqRouteQ, faqRouteA
    case faqFixQ, faqFixA
    case faqGatewayQ, faqGatewayA
    case faqKwQ, faqKwA
    case faqOcrQ, faqOcrA
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
    case vpnNotConnected
    case vpnImportClipboard
    case vpnImportFile
    case vpnDeleteAll
    case confirmDeleteProfile
    case confirmDeleteSelected
    case confirmDeleteAllProfiles
    case confirmRemoveDeadProfiles
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
    case btnPasteFromLink
    case linkPasted
    case linkPasteError
    case faqVpnQ
    case faqVpnA
    case faqDeepScanQ
    case faqDeepScanA
    
    // --- Подписки (Subscriptions) ---
    case vpnSubscriptions
    case subAddTitle
    case subName
    case subInterval
    case subUpdateAll
    case subUpdateNow
    case subDelete
    case subEnable
    case subDisable
    case subNoSubscriptions
    case subAddHint
    case subUsed
    case subExpires
    case subExpired
    case subLastUpdate
    case subNeverUpdated
    case subFilterAll
    case subFilterManual
    case subFilterHelp
    case groupLabel, groupNone, groupAll, groupFilterHelp, groupFieldPlaceholder, groupSetTitle
    case connStatsUptime, connStatsPort, connStatsTraffic, connStatsIn, connStatsOut
    case backupTitle, backupCreateTitle, backupCreateDesc, backupRestoreTitle, backupRestoreDesc
    case backupSaved, backupRestored, backupFailed, backupConfirmTitle, backupConfirmBody
    
    // --- QR для профилей VPN ---
    case vpnQrExport
    case vpnQrImportClipboard
    case vpnQrImportImage
    case vpnQrExportTitle
    case vpnQrCopyLink
    case vpnQrImportFound
    case vpnQrImportEmpty
    
    // --- Лог Xray & реальный тест профиля ---
    case vpnLogTitle
    case vpnLogEmpty
    case contextProxyTest
    case proxyTestTitle
    case proxyTestLatency
    case proxyTestSpeed
    case proxyTestRun

    // --- VPN: уведомления и ошибки соединения ---
    case vpnNotifyConnected
    case vpnNotifyDisconnected
    case vpnInstantCrash
    
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
        case labelAdvancedTransport
        case labelNone

        // --- Строки, добавленные при аудите локализации ---

        // VPN: кнопки и подсказки
        case btnImportProfile, btnShow, btnHide, helpDeleteOptions
        case unitMbps, helpAlpn

        // VPN: поля продвинутого транспорта
        case labelUuidPlain, labelSeed, labelQuicSecurity, labelQuicKey, labelAlpn

        // VPN: подписки
        case subUrlPlaceholder, subUserAgent
        case subIntervalHours, subIntervalDay, subIntervalDays

        // VPN: ошибки и статусы
        case vpnErrInvalidURL, vpnErrSubExists
        case proxyTestStarting, proxyTestMeasuringLatency, proxyTestMeasuringSpeed
        case proxyTestErrNoBinary, proxyTestErrConfig, proxyTestErrRun
        case proxyTestErrPort, proxyTestErrConnectivity

        // VPN: маршрутизация (детали правил и правила по умолчанию)
        case detailDomains, detailIPs, detailProtocol, detailAll
        case ruleBlockAds, ruleBypassLan, ruleBypassApple
        case ruleBypassTorrent, ruleProxyTelegram, ruleProxyGoogle



        // OCR
        case ocrDefaultVoice

        // AI: сообщения и ошибки
        case aiMsgDisabled, aiMsgNoKey, aiMsgNotConfigured
        case aiMsgBadOllamaURL, aiMsgBadProviderURL, aiMsgBadResponse, aiMsgUnknown
        case aiMsgInsufficient, aiMsgBadKey, aiMsgTooMany, aiMsgServerError, aiMsgApiErrorFmt
        case aiBalanceDeepSeekOnly, aiTestText
        case aiDebugRewrite, aiDebugImprove, aiDebugSummarize, aiDebugGeneric

        // --- VPN: редактор правил маршрутизации ---
        case routingRuleAdd, routingRuleEdit, routingRuleNew, routingRuleCopy
        case routingAction, routingOutProxy, routingOutDirect, routingOutBlock
        case routingFieldDomains, routingFieldIPs, routingFieldPorts
        case routingFieldProtocols, routingFieldNetwork, routingNetworkAny
        case routingEnabled, routingEmptyRules, routingConditions
        case routingHintDomains, routingHintIPs, routingHintPorts
        case btnDelete, btnDuplicate

        // Прочее (подписи интерфейса)
        case appTagline, subDefaultName

    // --- Localization Logic ---
    func localized(lang: AppLanguage) -> String {
        switch lang {
        case .russian: return LocalizationRU.string(self)
        case .english: return LocalizationEN.string(self)
        }
    }
}
