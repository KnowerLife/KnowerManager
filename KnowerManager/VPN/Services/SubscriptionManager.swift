import Foundation
import Combine

// MARK: - Менеджер подписок (Subscription Manager)

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var subscriptions: [VPNSubscription] = [] {
        didSet { save() }
    }

    /// Количество подписок, обновляющихся прямо сейчас.
    @Published private(set) var pendingCount = 0

    var isUpdatingAll: Bool { pendingCount > 0 }

    /// Последняя ошибка обновления (для показа в UI).
    @Published var lastError: String? = nil

    // MARK: - Internal

    private var updatingIds = Set<UUID>()
    private var autoUpdateTimer: Timer?

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("KnowerManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("subscriptions.json")
    }

    private init() {
        load()
        // Проверяем подписки на автообновление каждые 5 минут + после старта.
        autoUpdateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.updateDueSubscriptions()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.updateDueSubscriptions()
        }
    }

    // MARK: - Persistence

    private func save() {
        let snapshot = subscriptions
        DispatchQueue.global(qos: .background).async {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: Self.shared.storageURL)
            }
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([VPNSubscription].self, from: data) else { return }
        subscriptions = saved
        print("📂 Loaded \(saved.count) subscriptions from disk")
    }

    // MARK: - CRUD

    /// Добавляет подписку по URL и сразу обновляет её.
    @discardableResult
    func addSubscription(url: String, name: String = "", userAgent: String? = nil, updateIntervalHours: Int = 24) -> VPNSubscription? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"),
              let _ = URL(string: trimmed) else {
            lastError = "Invalid URL"
            return nil
        }
        // Не дублируем один и тот же URL.
        if subscriptions.contains(where: { $0.url == trimmed }) {
            lastError = "Subscription already exists"
            return nil
        }
        let sub = VPNSubscription(
            name: name,
            url: trimmed,
            userAgent: userAgent,
            updateIntervalHours: updateIntervalHours
        )
        subscriptions.append(sub)
        lastError = nil
        update(subscriptionId: sub.id)
        return sub
    }

    func removeSubscription(id: UUID) {
        XrayService.shared.removeProfiles(subscriptionId: id)
        subscriptions.removeAll { $0.id == id }
    }

    func toggleEnabled(id: UUID) {
        guard let i = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[i].isEnabled.toggle()
        if !subscriptions[i].isEnabled { return }
        // При включении — обновляем сразу.
        update(subscriptionId: id)
    }

    private func index(of id: UUID) -> Int? {
        subscriptions.firstIndex(where: { $0.id == id })
    }

    // MARK: - Update

    /// Обновляет подписки, у которых истёк интервал обновления.
    func updateDueSubscriptions() {
        let due = subscriptions.filter { $0.needsUpdate }
        for sub in due {
            update(subscriptionId: sub.id)
        }
    }

    func updateAll() {
        for sub in subscriptions where sub.isEnabled {
            update(subscriptionId: sub.id)
        }
    }

    /// Обновляет одну подписку (скачивает и разбирает список профилей).
    func update(subscriptionId: UUID) {
        guard let idx = index(of: subscriptionId), !updatingIds.contains(subscriptionId) else { return }
        let sub = subscriptions[idx]

        updatingIds.insert(subscriptionId)
        pendingCount = updatingIds.count

        Task { @MainActor in
            let result = await Self.fetch(subscription: sub)
            defer {
                self.updatingIds.remove(subscriptionId)
                self.pendingCount = self.updatingIds.count
            }
            switch result {
            case .success(let fetched):
                // Применяем профили (стабильные id для существующих серверов).
                XrayService.shared.applySubscriptionProfiles(
                    fetched.profiles,
                    subscriptionId: subscriptionId
                )
                if let i = self.index(of: subscriptionId) {
                    var s = self.subscriptions[i]
                    if let title = fetched.title,
                       !title.isEmpty,
                       (s.name.isEmpty || s.name == s.displayName) {
                        s.name = title
                    }
                    s.traffic = fetched.traffic
                    s.lastUpdate = Date()
                    self.subscriptions[i] = s
                }
                self.lastError = nil
                print("✅ Subscription updated: \(fetched.profiles.count) profiles")
            case .failure(let error):
                self.lastError = error.localizedDescription
                print("❌ Subscription update failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Fetch

    private static func fetch(subscription: VPNSubscription) async -> Result<SubscriptionFetchResult, Error> {
        guard let url = URL(string: subscription.url) else {
            return .failure(URLError(.badURL))
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        let ua = (subscription.userAgent?.isEmpty == false) ? subscription.userAgent! : "knmanager/1.0"
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        request.setValue("https://github.com/", forHTTPHeaderField: "Referer")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return .failure(URLError(.badServerResponse))
            }
            let headers = http.allHeaderFields
            let traffic = SubscriptionTrafficInfo.parse(
                header: caseInsensitiveHeader(headers, "subscription-userinfo") ?? ""
            )
            let titleRaw = caseInsensitiveHeader(headers, "profile-title") ?? ""
            let title = titleRaw.removingPercentEncoding ?? titleRaw

            guard let text = String(data: data, encoding: .utf8) else {
                return .failure(URLError(.cannotDecodeContentData))
            }
            let profiles = LinkParser.parseLinks(from: text)
            return .success(SubscriptionFetchResult(profiles: profiles, traffic: traffic, title: title))
        } catch {
            return .failure(error)
        }
    }

    private static func caseInsensitiveHeader(_ headers: [AnyHashable: Any], _ key: String) -> String? {
        let lower = key.lowercased()
        for (k, v) in headers {
            if let ks = k as? String, ks.lowercased() == lower {
                return v as? String
            }
        }
        return nil
    }
}