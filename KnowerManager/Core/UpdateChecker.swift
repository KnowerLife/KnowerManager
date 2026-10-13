import Foundation

// MARK: - Проверка обновлений через GitHub Releases
//
// Без внешних зависимостей: читает последний релиз репозитория через
// публичный GitHub API и сравнивает тег с версией текущего бандла.

enum UpdateChecker {

    static let releasesPageURL = URL(string: "https://github.com/KnowerLife/KnowerManager/releases")!
    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/KnowerLife/KnowerManager/releases/latest")!

    struct Result: Sendable {
        /// Тег последнего релиза (например, "v3.1").
        let latestTag: String
        /// Правда ли, что последний релиз новее установленной версии.
        let isNewer: Bool
        /// Ссылка на страницу релиза.
        let url: URL
    }

    /// Версия текущего приложения из Info.plist.
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Запрашивает последний релиз и сравнивает его с текущей версией.
    static func checkForUpdates() async throws -> Result {
        var request = URLRequest(url: latestReleaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let release = try JSONDecoder().decode(Release.self, from: data)
        let url = URL(string: release.html_url) ?? releasesPageURL
        return Result(latestTag: release.tag_name,
                      isNewer: compare(release.tag_name, currentVersion) > 0,
                      url: url)
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }

    /// Сравнивает версии вида «v3.0», «3.1.2». Возвращает >0, если `a` новее `b`.
    static func compare(_ a: String, _ b: String) -> Int {
        let na = normalize(a)
        let nb = normalize(b)
        let count = max(na.count, nb.count)
        for i in 0..<count {
            let x = i < na.count ? na[i] : 0
            let y = i < nb.count ? nb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }

    private static func normalize(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .split(separator: ".")
            .map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }
}
