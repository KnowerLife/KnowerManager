import SwiftUI
import AppKit

struct SSConnectionView: View {
    @StateObject var xray = XrayService.shared
    @ObservedObject var subs = SubscriptionManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var routing = RoutingManager.shared
    
    // Поиск
    @State private var searchText = ""
    
    // Состояния UI
    @State private var isSortedByPing = false
    @State private var showRouting = false
    @State private var showSubscriptions = false
    
    // Фильтр по источнику (все / ручные / конкретная подписка)
    enum ProfileFilter: Hashable {
        case all
        case manual
        case subscription(UUID)
    }
    @State private var profileFilter: ProfileFilter = .all
    
    // Фильтр по группе (nil = все группы)
    @State private var groupFilter: String? = nil
    
    /// Все группы, встречающиеся среди профилей (отсортированные).
    private var availableGroups: [String] {
        let all = xray.profiles.compactMap { $0.group?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set(all.filter { !$0.isEmpty })).sorted()
    }
    
    // --- МУЛЬТИ-ВЫБОР ---
    @State private var selectedIds = Set<UUID>()
    
    // --- РЕДАКТИРОВАНИЕ ---
    @State private var profileToEdit: ShadowsocksProfile?
    
    // --- QR ЭКСПОРТ ---
    @State private var qrExportProfile: ShadowsocksProfile?
    
    // --- ТЕСТ ПРОФИЛЯ / ЛОГ ---
    @State private var testProfile: ShadowsocksProfile?
    @State private var isLogExpanded = false
    
    // --- ОПТИМИЗАЦИЯ: СПИСОК ДЛЯ ОТОБРАЖЕНИЯ ---
    @State private var displayedProfiles: [ShadowsocksProfile] = []
    @State private var searchTask: DispatchWorkItem?
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ==========================================
            // 1. COMPACT HEADER (Title + Status + Routing)
            // ==========================================
            HStack(alignment: .center, spacing: 12) {
                // Лого и Заголовок
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.t(.vpnTitle))
                            .font(.system(size: 14, weight: .bold))
                        Text("\(xray.profiles.count) \(settings.t(.vpnProfilesLoaded))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Статус подключения (Compact Pill)
                if xray.isRunning {
                    HStack(spacing: 6) {
                        PulsingDot()
                        Text(settings.t(.vpnConnected))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3), lineWidth: 1))
                }
                
                // Кнопка Маршрутизации
                Button(action: { showRouting = true }) {
                    let icon = routing.mode == .global ? "globe" :
                    (routing.mode == .direct ? "arrow.up.left.and.arrow.down.right" : "list.bullet.rectangle.portrait")
                    
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(settings.t(.routingTitle)) // Tooltip
                .sheet(isPresented: $showRouting) { RoutingView() }
                
                // Кнопка «Открыть папку данных»
                Button(action: { xray.openDataFolder() }) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(settings.t(.vpnOpenDataFolder))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignSystem.cardColor)
            
            Divider()
            
            // ==========================================
            // 2. CONTROL BAR (Search + Actions)
            // ==========================================
            HStack(spacing: 12) {
                // Поиск (Слева)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField(settings.t(.vpnSearchPlaceholder), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onChange(of: searchText) { _ in performSearch() }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                
                // Фильтр по источнику (виден, если есть подписки)
                if !subs.subscriptions.isEmpty {
                    Menu {
                        Button {
                            profileFilter = .all
                        } label: {
                            Label(settings.t(.subFilterAll), systemImage: "tray.full")
                            if profileFilter == .all { Image(systemName: "checkmark") }
                        }
                        Button {
                            profileFilter = .manual
                        } label: {
                            Label(settings.t(.subFilterManual), systemImage: "pencil.and.scribble")
                            if profileFilter == .manual { Image(systemName: "checkmark") }
                        }
                        Divider()
                        ForEach(subs.subscriptions) { sub in
                            Button {
                                profileFilter = .subscription(sub.id)
                            } label: {
                                Label(sub.displayName, systemImage: "arrow.triangle.2.circlepath")
                                if profileFilter == .subscription(sub.id) { Image(systemName: "checkmark") }
                            }
                        }
                    } label: {
                        IconBtn(icon: "line.3.horizontal.decrease.circle",
                                color: profileFilter == .all ? .primary : .blue)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28, height: 28)
                    .help(settings.t(.subFilterHelp))
                }
                
                // Фильтр по группе (виден, если есть хотя бы одна группа)
                if !availableGroups.isEmpty {
                    Menu {
                        Button {
                            groupFilter = nil
                        } label: {
                            Label(settings.t(.groupAll), systemImage: "square.grid.2x2")
                            if groupFilter == nil { Image(systemName: "checkmark") }
                        }
                        Divider()
                        ForEach(availableGroups, id: \.self) { g in
                            Button {
                                groupFilter = g
                            } label: {
                                Label(g, systemImage: "folder")
                                if groupFilter == g { Image(systemName: "checkmark") }
                            }
                        }
                    } label: {
                        IconBtn(icon: "folder.badge.gearshape",
                                color: groupFilter == nil ? .primary : .orange)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28, height: 28)
                    .help(settings.t(.groupFilterHelp))
                }
                
                // Действия (Справа)
                HStack(spacing: 4) {
                    
                    // A. Подписки
                    Button(action: { showSubscriptions = true }) {
                        IconBtn(icon: "arrow.triangle.2.circlepath.circle",
                                color: !subs.subscriptions.isEmpty ? .blue : .primary)
                    }
                    .buttonStyle(.plain)
                    .help(settings.t(.vpnSubscriptions))
                    
                    // B. Import
                    Menu {
                        Button { xray.importFromClipboard() } label: { Label(settings.t(.vpnImportClipboard), systemImage: "doc.on.clipboard") }
                        Button { xray.importFromFile() } label: { Label(settings.t(.vpnImportFile), systemImage: "doc.text") }
                        Divider()
                        Button { xray.importFromQRClipboard() } label: { Label(settings.t(.vpnQrImportClipboard), systemImage: "qrcode.viewfinder") }
                        Button { xray.importFromQRImageFile() } label: { Label(settings.t(.vpnQrImportImage), systemImage: "photo") }
                        Divider()
                        Button { showSubscriptions = true } label: { Label(settings.t(.vpnImportUrl), systemImage: "link") }
                        Divider()
                        Button {
                            let newProfile = ShadowsocksProfile(name: "New Profile", protocolType: .vless)
                            profileToEdit = newProfile
                        } label: { Label(settings.t(.btnCreateProfile), systemImage: "plus.square.dashed") }
                    } label: {
                        IconBtn(icon: "plus", color: .blue)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28, height: 28)
                    .help(settings.t(.btnImport))
                    
                    // B. Ping / Smart Action
                    Group {
                        if !selectedIds.isEmpty {
                            // Ping Selected
                            Button(action: { xray.pingProfiles(ids: selectedIds) }) {
                                IconBtn(icon: "bolt.fill", color: .orange, isActive: true)
                            }
                            .help(settings.t(.btnPingSelected))
                        } else {
                            // Ping Menu
                            Menu {
                                Button { xray.pingAllProfiles(autoSelect: true) } label: { Label(settings.t(.vpnPingAll), systemImage: "bolt.fill") }
                                Divider()
                                if xray.isDeepScanning {
                                    Button { xray.stopDeepScan() } label: { Label(settings.t(.vpnStopScan), systemImage: "stop.circle.fill") }
                                } else {
                                    Button { xray.startDeepScan(limit: 20) } label: { Label(settings.t(.vpnDeepScan), systemImage: "checkmark.shield") }
                                    Button { xray.startDeepScan(limit: nil) } label: { Label(settings.t(.vpnCheckAll), systemImage: "exclamationmark.shield") }
                                }
                            } label: {
                                if xray.isPinging || xray.isDeepScanning {
                                    ProgressView().controlSize(.small).scaleEffect(0.7)
                                } else {
                                    IconBtn(icon: "bolt", color: .primary)
                                }
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 28, height: 28)
                            .help(settings.t(.vpnPingAll))
                        }
                    }
                    .buttonStyle(.plain)

                    // C. Sort
                    Button(action: {
                        isSortedByPing.toggle()
                        performSearch()
                    }) {
                        IconBtn(icon: isSortedByPing ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle",
                                color: isSortedByPing ? .blue : .primary)
                    }
                    .buttonStyle(.plain)
                    .help(settings.t(.vpnSortByPing))
                    
                    // D. Delete
                    Menu {
                        if !selectedIds.isEmpty {
                            Button { deleteSelected() } label: { Label("\(settings.t(.contextDelete)) \(selectedIds.count)", systemImage: "trash.fill") }
                            Divider()
                        }
                        Button { confirmRemoveDead() } label: { Label(settings.t(.vpnRemoveDead), systemImage: "wifi.slash") }
                        Button { confirmDeleteAll() } label: { Label(settings.t(.vpnDeleteAll), systemImage: "trash") }
                    } label: {
                        IconBtn(icon: "trash", color: !selectedIds.isEmpty ? .red : .primary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28, height: 28)
                    .help(settings.t(.helpDeleteOptions))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // ==========================================
            // 3. MAIN LIST
            // ==========================================
            if xray.profiles.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.2))
                    Text(settings.t(.vpnNoProfiles))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button(settings.t(.btnImportProfile)) { showSubscriptions = true }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(DesignSystem.cardColor)
            } else {
                List(selection: $selectedIds) {
                    ForEach(displayedProfiles) { profile in
                        ProfileRow(profile: profile, isSelected: xray.selectedProfileId == profile.id, isPinging: xray.isPinging)
                            .contentShape(Rectangle())
                            .contextMenu {
                                // Контекстное меню вынесено в Row для чистоты
                                ProfileContextMenu(profile: profile, selectedIds: selectedIds,
                                                   groups: availableGroups,
                                                   onPing: { xray.pingProfiles(ids: [$0]) },
                                                   onEdit: { profileToEdit = $0 },
                                                   onConnect: { xray.selectedProfileId = $0; xray.toggleConnection() },
                                                   onShare: { qrExportProfile = $0 },
                                                   onTest: { testProfile = $0 },
                                                   onFavorite: { xray.toggleFavorite(id: $0) },
                                                   onSetGroup: { prof, g in
                                    var updated = prof
                                    updated.group = g
                                    xray.updateProfile(updated)
                                },
                                                   onDelete: { _ in
                                    if selectedIds.contains(profile.id) { deleteSelected() }
                                    else { confirmDeleteSingle(profile) }
                                })
                            }
                            .onTapGesture(count: 2) {
                                connectTo(profile)
                            }
                            .onTapGesture {
                                xray.selectedProfileId = profile.id
                            }
                    }
                }
                .listStyle(.inset)
                .onDeleteCommand { if !selectedIds.isEmpty { deleteSelected() } }
            }
            
            Divider()
            
            // ==========================================
            // 4. BIG CONNECT BUTTON
            // ==========================================
            HStack {
                Button(action: { xray.toggleConnection() }) {
                    HStack {
                        Image(systemName: "power")
                            .font(.system(size: 16, weight: .bold))
                        Text(xray.isRunning ? settings.t(.btnDisconnect) : settings.t(.btnConnect))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        xray.isRunning ? Color.red : (xray.selectedProfileId == nil ? Color.gray.opacity(0.5) : Color.blue)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: (xray.isRunning ? Color.red : Color.blue).opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(xray.selectedProfileId == nil && !xray.isRunning)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // ==========================================
            // 5. XRAY LOG (сворачиваемый)
            // ==========================================
            VStack(spacing: 0) {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isLogExpanded.toggle() } }) {
                    HStack(spacing: 6) {
                        Circle().fill(xray.isRunning ? Color.green : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(settings.t(.vpnLogTitle))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(settings.t(isLogExpanded ? .btnHide : .btnShow))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Image(systemName: isLogExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                
                if isLogExpanded {
                    ScrollViewReader { reader in
                        ScrollView {
                            Text(xray.xrayLog.isEmpty ? settings.t(.vpnLogEmpty) : xray.xrayLog)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(xray.isRunning ? Color.green : Color.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .id("logBottom")
                                .onChange(of: xray.xrayLog) { _ in
                                    reader.scrollTo("logBottom", anchor: .bottom)
                                }
                        }
                        .frame(height: 90)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .padding(.bottom, isLogExpanded ? 8 : 16)
            .background(DesignSystem.cardColor)
        }
        .background(DesignSystem.cardColor)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.cardStroke, lineWidth: 1))
        
        // --- OVERLAYS & SHEETS ---
        .overlay {
            if xray.isImporting { LoadingOverlay(text: settings.t(.vpnImporting)) }
            else if xray.isDeepScanning { DeepScanOverlay(current: xray.scanProgress.current, total: xray.scanProgress.total, onStop: { xray.stopDeepScan() }) }
        }
        .sheet(isPresented: $showSubscriptions) { SubscriptionsView() }
        .sheet(item: $profileToEdit) { profile in
            ProfileEditView(profile: $profileToEdit, onSave: { xray.updateProfile($0) })
        }
        .sheet(item: $qrExportProfile) { profile in
            ProfileQRExportView(profile: profile)
        }
        .sheet(item: $testProfile) { profile in
            ProfileSpeedTestView(profile: profile)
        }
        .onReceive(xray.$profiles) { _ in performSearch() }
        .onReceive(subs.$subscriptions) { _ in performSearch() }
        .onChange(of: profileFilter) { _ in performSearch() }
        .onChange(of: groupFilter) { _ in performSearch() }
        .onAppear { performSearch() }
    }
    
    // --- ACTIONS ---
    /// Двойной клик по профилю: подключиться к нему, а если он уже активен — отключиться.
    func connectTo(_ profile: ShadowsocksProfile) {
        if xray.isRunning && xray.activeProfileId == profile.id {
            xray.stop()
        } else {
            xray.selectedProfileId = profile.id
            xray.start(profile: profile)
        }
    }
    
    func deleteSelected() {
        guard !selectedIds.isEmpty else { return }
        let count = selectedIds.count
        let title = String(format: settings.t(.confirmDeleteSelected), "\(count)")
        guard confirmDestructive(title) else { return }
        performDeleteSelected()
    }
    
    private func performDeleteSelected() {
        // Если удаляем профиль активного соединения — сначала корректно отключаемся.
        if let active = xray.activeProfileId, selectedIds.contains(active) { xray.stop() }
        xray.profiles.removeAll { selectedIds.contains($0.id) }
        if let current = xray.selectedProfileId, selectedIds.contains(current) {
            xray.selectedProfileId = nil
        }
        selectedIds.removeAll()
        performSearch()
    }
    
    /// Удаление одного профиля из контекстного меню — с подтверждением.
    func confirmDeleteSingle(_ profile: ShadowsocksProfile) {
        let title = String(format: settings.t(.confirmDeleteProfile), profile.name)
        guard confirmDestructive(title) else { return }
        xray.removeProfile(id: profile.id)
        performSearch()
    }
    
    /// Удаление подтверждённо недоступных профилей — с подтверждением.
    func confirmRemoveDead() {
        guard confirmDestructive(settings.t(.confirmRemoveDeadProfiles)) else { return }
        xray.removeDeadProfiles()
        performSearch()
    }
    
    /// Полное удаление всех профилей — с подтверждением.
    func confirmDeleteAll() {
        guard confirmDestructive(settings.t(.confirmDeleteAllProfiles)) else { return }
        xray.stop()
        xray.profiles.removeAll()
        xray.selectedProfileId = nil
        selectedIds.removeAll()
        performSearch()
    }
    
    /// Нативный macOS-диалог подтверждения. Возвращает true, если пользователь подтвердил.
    private func confirmDestructive(_ title: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.alertStyle = .warning
        alert.addButton(withTitle: settings.t(.btnDelete))
        alert.addButton(withTitle: settings.t(.btnCancel))
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    func performSearch() {
        searchTask?.cancel()
        // Снимок входных данных делаем на главном потоке: чтение @State и
        // @Published из фоновой очереди — гонка данных.
        let query = searchText
        let snapshot = xray.profiles
        let sortedByPing = isSortedByPing
        let filter = profileFilter
        let group = groupFilter
        let task = DispatchWorkItem {
            var result = snapshot
            // Фильтр по источнику
            switch filter {
            case .all: break
            case .manual:
                result = result.filter { $0.subscriptionId == nil }
            case .subscription(let id):
                result = result.filter { $0.subscriptionId == id }
            }
            // Фильтр по группе
            if let group = group {
                result = result.filter { ($0.group ?? "") == group }
            }
            if !query.isEmpty {
                result = result.filter {
                    $0.name.localizedCaseInsensitiveContains(query) ||
                    $0.server.localizedCaseInsensitiveContains(query) ||
                    $0.protocolType.rawValue.localizedCaseInsensitiveContains(query)
                }
            }
            if sortedByPing {
                result.sort { p1, p2 in
                    let l1 = p1.latency ?? Int.max
                    let l2 = p2.latency ?? Int.max
                    return l1 < l2
                }
            } else {
                 // Sort by favorites first
                 result.sort { p1, p2 in p1.isBookmarked && !p2.isBookmarked }
            }
            DispatchQueue.main.async { self.displayedProfiles = result }
        }
        searchTask = task
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1, execute: task)
    }
}

// ==========================================
// SUBVIEWS (Для чистоты кода)
// ==========================================

// 1. Иконка-кнопка для тулбара
struct IconBtn: View {
    let icon: String
    let color: Color
    var isActive: Bool = false
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14))
            .foregroundColor(isActive ? .white : color)
            .frame(width: 28, height: 28)
            .background(isActive ? color : Color.gray.opacity(0.1))
            .cornerRadius(6)
    }
}

// 2. Строка профиля
struct ProfileRow: View {
    let profile: ShadowsocksProfile
    let isSelected: Bool
    let isPinging: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Radio Indicator
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    if profile.isBookmarked {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow)
                    }
                }
                
                HStack(spacing: 6) {
                    if let group = profile.group, !group.isEmpty {
                        ProtocolBadge(text: group, color: .orange)
                    }
                    ProtocolBadge(text: profile.protocolType.rawValue.uppercased(), color: .blue)
                    if let sec = profile.security, sec != "none" {
                        ProtocolBadge(text: sec.uppercased(), color: .purple)
                    }
                    Text(profile.server)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Ping Badge
            if let ms = profile.latency {
                Text(ms < 0 ? "DEAD" : "\(ms) ms")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(pingColor(ms).opacity(0.2))
                    .foregroundColor(pingColor(ms))
                    .cornerRadius(4)
            } else if isPinging {
                ProgressView().scaleEffect(0.5)
            }
        }
        .padding(.vertical, 4)
    }
    
    func pingColor(_ ms: Int) -> Color {
        if ms < 0 { return .red }
        if ms < 150 { return .green }
        if ms < 300 { return .orange }
        return .red
    }
}

struct ProtocolBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(3)
    }
}

// 3. Контекстное меню
struct ProfileContextMenu: View {
    let profile: ShadowsocksProfile
    let selectedIds: Set<UUID>
    let groups: [String]
    let onPing: (UUID) -> Void
    let onEdit: (ShadowsocksProfile) -> Void
    let onConnect: (UUID) -> Void
    let onShare: (ShadowsocksProfile) -> Void
    let onTest: (ShadowsocksProfile) -> Void
    let onFavorite: (UUID) -> Void
    let onSetGroup: (ShadowsocksProfile, String?) -> Void
    let onDelete: (UUID) -> Void
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        Button { onConnect(profile.id) } label: { Label(settings.t(.contextConnect), systemImage: "power") }
        Button { onPing(profile.id) } label: { Label(settings.t(.contextPing), systemImage: "bolt") }
        Divider()
        Button { onEdit(profile) } label: { Label(settings.t(.contextEdit), systemImage: "pencil") }
        Menu {
            Button(settings.t(.groupNone)) { onSetGroup(profile, nil) }
            if !groups.isEmpty {
                Divider()
                ForEach(groups, id: \.self) { g in
                    Button(g) { onSetGroup(profile, g) }
                }
            }
        } label: {
            Label(settings.t(.groupSetTitle), systemImage: "folder")
        }
        Button { onShare(profile) } label: { Label(settings.t(.vpnQrExport), systemImage: "qrcode") }
        Button { onTest(profile) } label: { Label(settings.t(.contextProxyTest), systemImage: "speedometer") }
        Button { onFavorite(profile.id) } label: { Label(profile.isBookmarked ? settings.t(.contextUnfavorite) : settings.t(.contextFavorite), systemImage: "star") }
        Divider()
        Button { onDelete(profile.id) } label: { Label(settings.t(.contextDelete), systemImage: "trash") }
    }
}

// 4. Оверлеи
struct LoadingOverlay: View {
    let text: String
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).cornerRadius(12)
            VStack(spacing: 12) {
                ProgressView().controlSize(.large).tint(.white)
                Text(text).font(.headline).foregroundColor(.white)
            }.padding(24).background(Color("CardBackground")).cornerRadius(16)
        }
    }
}

struct DeepScanOverlay: View {
    let current: Int; let total: Int; let onStop: () -> Void
    @ObservedObject var settings = SettingsManager.shared
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).cornerRadius(12)
            VStack(spacing: 16) {
                ProgressView().controlSize(.large).tint(.white)
                Text("\(current) / \(total)").font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundColor(.white)
                Button(action: onStop) {
                    Text(settings.t(.btnStop)).foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 6).background(Color.red).cornerRadius(8)
                }.buttonStyle(.plain)
            }.padding(30).background(Color.black.opacity(0.5)).cornerRadius(16)
        }
    }
}

struct PulsingDot: View {
    @State private var animate = false
    var body: some View {
        Circle().fill(Color.green).frame(width: 8, height: 8)
            .scaleEffect(animate ? 1.2 : 1.0)
            .opacity(animate ? 0.6 : 1.0)
            .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { animate = true } }
    }
}
