import Foundation

// MARK: - Проверка обновлений через GitHub
//
// Без внешних зависимостей: читает список релизов репозитория через публичный
// GitHub API и сравнивает тег с версией текущего бандла.
//
// Почему НЕ /releases/latest: если релизы ещё не публиковались (или есть только
// теги), этот эндпоинт отдаёт 404, и проверка всегда падала с «не удалось
// проверить обновления». Вместо него берём список /releases (при отсутствии
// релизов он возвращает пустой массив, а не ошибку) и, если он пуст, — /tags.

enum UpdateChecker {

    static let releasesPageURL = URL(string: "https://github.com/KnowerLife/KnowerManager/releases")!
    private static let apiBase = "https://api.github.com/repos/KnowerLife/KnowerManager"

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

    /// Запрашивает последний релиз/тег и сравнивает его с версией приложения.
    /// Не бросает ошибку, если релизов ещё нет — в этом случае возвращает
    /// «обновлений нет».
    static func checkForUpdates() async throws -> Result {
        // 1. Список релизов (сначала самый свежий).
        if let release = try await firstRelease() {
            return makeResult(tag: release.tag, url: release.url)
        }

        // 2. Релизов нет — пробуем теги (например, если публикуются только теги).
        if let tag = try await latestTag() {
            let url = URL(string: "\(releasesPageURL.absoluteString)/tag/\(tag)") ?? releasesPageURL
            return makeResult(tag: tag, url: url)
        }

        // 3. Ни релизов, ни тегов — считаем, что установлена последняя версия.
        return Result(latestTag: currentVersion, isNewer: false, url: releasesPageURL)
    }

    // MARK: - Сеть

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }

    private struct Tag: Decodable {
        let name: String
    }

    private static func request(path: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "\(apiBase)/\(path)")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub API требует User-Agent.
        request.setValue("KnowerManager", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        return request
    }

    private static func decode<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request(path: path))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func firstRelease() async throws -> (tag: String, url: URL)? {
        let releases = try await decode([Release].self, path: "releases?per_page=1")
        guard let first = releases.first else { return nil }
        return (first.tag_name, URL(string: first.html_url) ?? releasesPageURL)
    }

    private static func latestTag() async throws -> String? {
        let tags = try await decode([Tag].self, path: "tags?per_page=1")
        return tags.first?.name
    }

    private static func makeResult(tag: String, url: URL) -> Result {
        Result(latestTag: tag, isNewer: compare(tag, currentVersion) > 0, url: url)
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
