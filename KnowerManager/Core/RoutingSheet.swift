import SwiftUI

struct RoutingSheet: View {
    @ObservedObject var manager = KnowerManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var newDomain = ""
    @State private var downloadUrl = "" // Поле для URL
    @State private var isDownloading = false
    
    var body: some View {
        VStack(spacing: 0) {
            
            // --- HEADER ---
            VStack(spacing: 12) {
                HStack {
                    Text(settings.t(.routingTitle))
                        .font(.headline)
                    Spacer()
                    Button(settings.t(.btnDone)) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.blue)
                }
                
                // 1. ПЕРЕКЛЮЧАТЕЛЬ РЕЖИМОВ (3 позиции)
                Picker("", selection: $manager.routingMode) {
                    Text(settings.t(.routingModeGlobal)).tag(RoutingMode.global)
                    Text(settings.t(.routingModeList)).tag(RoutingMode.onlyList)
                    Text(settings.t(.routingModeExclude)).tag(RoutingMode.exclude) // Новый режим
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding()
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            
            // --- CONTENT ---
            if manager.routingMode == .global {
                // GLOBAL MODE VIEW
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "globe.europe.africa.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue.opacity(0.2))
                    
                    Text(settings.t(.routingModeGlobal))
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(settings.t(.routingGlobalDesc))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
            } else {
                // LIST EDITOR (Работает и для OnlyList, и для Exclude)
                VStack(spacing: 12) {
                    
                    // A. ВВОД ДОМЕНА ВРУЧНУЮ
                    HStack(spacing: 8) {
                        TextField(settings.t(.hostPlaceholder), text: $newDomain)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .onSubmit { addDomain() }
                        
                        Button(action: addDomain) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    // B. ЗАГРУЗКА ПО URL (Новая секция)
                    HStack(spacing: 8) {
                        TextField(settings.t(.urlPlaceholder), text: $downloadUrl)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 11))
                            .padding(6)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        
                        Button(action: {
                            guard !downloadUrl.isEmpty else { return }
                            isDownloading = true
                            manager.downloadHostlist(from: downloadUrl)
                            downloadUrl = "" // Очистить поле
                            // Сброс анимации через секунду
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { isDownloading = false }
                        }) {
                            if isDownloading {
                                ProgressView().scaleEffect(0.5)
                            } else {
                                Image(systemName: "icloud.and.arrow.down")
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 24)
                        .help(settings.t(.btnDownload))
                    }
                    .padding(.horizontal)
                    
                    // C. СПИСОК
                    List {
                        ForEach(manager.userDomains, id: \.self) { domain in
                            HStack {
                                Image(systemName: manager.routingMode == .exclude ? "xmark.shield" : "globe")
                                    .font(.system(size: 12))
                                    .foregroundColor(manager.routingMode == .exclude ? .red.opacity(0.7) : .blue.opacity(0.8))
                                
                                Text(domain)
                                    .font(.system(size: 13, design: .monospaced))
                                
                                Spacer()
                                
                                Button(action: {
                                    if let index = manager.userDomains.firstIndex(of: domain) {
                                        manager.removeDomain(at: IndexSet(integer: index))
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listStyle(InsetListStyle())
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // D. FOOTER
                    HStack(spacing: 10) {
                        // Импорт файла
                        Button(action: { manager.importHostlist() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                Text(settings.t(.btnImport))
                            }
                            .font(.system(size: 11))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Экспорт
                        Button(action: { manager.exportHostlist() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text(settings.t(.exportMessage)) // "Сохранить..."
                            }
                            .font(.system(size: 11))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        // Очистка
                        Button(action: {
                            withAnimation { manager.userDomains.removeAll() }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 380, height: 500)
    }
    
    func addDomain() {
        if !newDomain.isEmpty {
            withAnimation { manager.addDomain(newDomain) }
            newDomain = ""
        }
    }
}
