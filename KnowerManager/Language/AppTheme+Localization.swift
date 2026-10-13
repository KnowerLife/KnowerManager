import Foundation

// MARK: - Локализация названий темы оформления

extension AppTheme {
    /// Название темы на выбранном языке интерфейса.
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
