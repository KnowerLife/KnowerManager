import Foundation

// MARK: - Тип инструмента
enum ToolType: String, Codable {
    case action
    case toggle
    case info
}

// MARK: - Модель инструмента
struct Tool: Identifiable, Codable, Equatable {
    let id: String
    let titleKey: StringKey
    let descKey: StringKey?
    let type: ToolType
    let needsPriv: Bool
    var enabled: Bool
    var showInMiniMenu: Bool
    
    init(
        id: String,
        titleKey: StringKey,
        descKey: StringKey? = nil,
        type: ToolType,
        needsPriv: Bool = false,
        enabled: Bool = true,
        showInMiniMenu: Bool = false
    ) {
        self.id = id
        self.titleKey = titleKey
        self.descKey = descKey
        self.type = type
        self.needsPriv = needsPriv
        self.enabled = enabled
        self.showInMiniMenu = showInMiniMenu
    }
}
