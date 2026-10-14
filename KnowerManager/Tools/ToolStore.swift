import Foundation
import Combine

final class ToolStore: ObservableObject {
    static let shared = ToolStore()
    
    @Published var tools: [Tool] = ToolStore.defaultTools
    
    // Храним состояния
    private let enabledPrefix = "tool.enabled."
    private let showMiniPrefix = "tool.showmini."
    
    private init() {
        loadStates()
        restoreKeepAwakeIfNeeded()
    }
    
    private static var defaultTools: [Tool] {
        [
            Tool(
                id: "networkInfo",
                titleKey: .toolNetworkInfoTitle,
                descKey: .toolNetworkInfoDesc,
                type: .info,
                needsPriv: false,
                enabled: true,
                showInMiniMenu: false
            ),
            Tool(
                id: "keepAwake",
                titleKey: .toolKeepAwakeTitle,
                descKey: .toolKeepAwakeDesc,
                type: .toggle,
                needsPriv: false,
                enabled: false,
                showInMiniMenu: false
            ),
            Tool(
                id: "dnsLookup",
                titleKey: .toolDnsLookupTitle,
                descKey: .toolDnsLookupDesc,
                type: .action,
                needsPriv: false,
                enabled: true,
                showInMiniMenu: false
            ),
            Tool(
                id: "arpFlush",
                titleKey: .toolArpFlushTitle,
                descKey: .toolArpFlushDesc,
                type: .action,
                needsPriv: true,
                enabled: true,
                showInMiniMenu: false
            )
        ]
    }
    
    private func loadStates() {
        for i in tools.indices {
            let id = tools[i].id
            let enabledKey = enabledPrefix + id
            let showKey = showMiniPrefix + id
            if UserDefaults.standard.object(forKey: enabledKey) != nil {
                tools[i].enabled = UserDefaults.standard.bool(forKey: enabledKey)
            }
            if UserDefaults.standard.object(forKey: showKey) != nil {
                tools[i].showInMiniMenu = UserDefaults.standard.bool(forKey: showKey)
            }
        }
    }
    
    func saveEnabled(_ id: String, _ value: Bool) {
        if let idx = tools.firstIndex(where: { $0.id == id }) {
            tools[idx].enabled = value
            UserDefaults.standard.set(value, forKey: enabledPrefix + id)
            if id == "keepAwake" {
                if value { start(id: id) } else { stop(id: id) }
            }
        }
    }
    
    func saveShowInMini(_ id: String, _ value: Bool) {
        if let idx = tools.firstIndex(where: { $0.id == id }) {
            tools[idx].showInMiniMenu = value
            UserDefaults.standard.set(value, forKey: showMiniPrefix + id)
        }
    }
    
    func start(id: String) {
        switch id {
        case "keepAwake":
            KeepAwakeManager.shared.start()
        default:
            break
        }
    }
    
    func stop(id: String) {
        switch id {
        case "keepAwake":
            KeepAwakeManager.shared.stop()
        default:
            break
        }
    }
    
    private func restoreKeepAwakeIfNeeded() {
        if let tool = tools.first(where: { $0.id == "keepAwake" }), tool.enabled {
            KeepAwakeManager.shared.start()
        }
    }
    
    func tool(for id: String) -> Tool? {
        tools.first(where: { $0.id == id })
    }
}
