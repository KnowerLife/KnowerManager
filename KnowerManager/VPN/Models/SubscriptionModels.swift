import Foundation

// MARK: - Информация о трафике подписки (заголовок `subscription-userinfo`)

struct SubscriptionTrafficInfo: Codable, Hashable {
    var upload: Int64? = nil
    var download: Int64? = nil
    var total: Int64? = nil
    var expire: Int64? = nil

    var usedBytes: Int64 { (upload ?? 0) + (download ?? 0) }
    var totalBytes: Int64 { total ?? 0 }

    var hasQuota: Bool { totalBytes > 0 }

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1.0, Double(usedBytes) / Double(totalBytes))
    }

    var expiryDate: Date? {
        guard let e = expire, e > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(e))
    }

    /// Разбирает заголовок вида: `upload=123; download=456; total=1073741824; expire=1700000000`
    static func parse(header: String) -> SubscriptionTrafficInfo? {
        var info = SubscriptionTrafficInfo()
        var found = false
        for part in header.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1)
            guard kv.count == 2, let value = Int64(kv[1].trimmingCharacters(in: .whitespacesAndNewlines)) else { continue }
            switch kv[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "upload": info.upload = value; found = true
            case "download": info.download = value; found = true
            case "total": info.total = value; found = true
            case "expire": info.expire = value; found = true
            default: break
            }
        }
        return found ? info : nil
    }
}

// MARK: - Подписка

struct VPNSubscription: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var url: String
    var userAgent: String? = nil
    var updateIntervalHours: Int = 24
    var lastUpdate: Date? = nil
    var traffic: SubscriptionTrafficInfo? = nil
    var isEnabled: Bool = true

    var displayName: String {
        if !name.isEmpty { return name }
        if let host = URL(string: url)?.host, !host.isEmpty { return host }
        return SettingsManager.shared.t(.subDefaultName)
    }

    var nextUpdate: Date? {
        guard isEnabled, let last = lastUpdate else { return nil }
        return last.addingTimeInterval(TimeInterval(updateIntervalHours) * 3600)
    }

    var needsUpdate: Bool {
        guard isEnabled else { return false }
        if lastUpdate == nil { return true }
        return nextUpdate ?? .distantPast < Date()
    }
}

// MARK: - Результат обновления подписки

struct SubscriptionFetchResult {
    var profiles: [ShadowsocksProfile] = []
    var traffic: SubscriptionTrafficInfo? = nil
    var title: String? = nil
}