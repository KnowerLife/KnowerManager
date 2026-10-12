import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var tools: ToolsManager
    @ObservedObject var settings: SettingsManager
    @State private var targetURL = ""
    @State private var isFlushingDNS = false
    @State private var dnsFlushSuccess = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Иконка
            Image(systemName: "stethoscope.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
            
            Text(settings.t(.diagTitle))
                .font(.headline)
            
            // Поле ввода и кнопка проверки
            HStack {
                TextField(settings.t(.diagPlaceholder), text: $targetURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                    .onSubmit { tools.checkConnection(url: targetURL) }
                
                Button(settings.t(.diagCheckBtn)) {
                    tools.checkConnection(url: targetURL)
                }
                .buttonStyle(ModernButtonStyle(color: .blue))
                .frame(width: 100)
            }
            
            // Результат проверки соединения
            if let status = tools.connectionStatus {
                HStack {
                    Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(status ? .green : .red)
                    Text(status ? settings.t(.diagSuccess) : settings.t(.diagFail))
                        .font(.system(size: 14, weight: .medium))
                }
                .padding()
                .background(DesignSystem.cardColor)
                .cornerRadius(10)
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // Кнопка сброса DNS (Исправленная)
            Button(action: {
                flushDNSAction()
            }) {
                HStack {
                    if isFlushingDNS {
                        ProgressView().scaleEffect(0.5).frame(width: 16, height: 16)
                    } else if dnsFlushSuccess {
                        Image(systemName: "checkmark").foregroundColor(.green)
                    } else {
                        Image(systemName: "trash")
                    }
                    
                    Text(dnsFlushSuccess ? settings.t(.flushDnsSuccess) : settings.t(.flushDnsBtn))
                        .foregroundColor(dnsFlushSuccess ? .green : .secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isFlushingDNS)
            .padding(.bottom)
        }
    }
    
    // Логика сброса DNS с анимацией
    private func flushDNSAction() {
        withAnimation { isFlushingDNS = true }
        
        // Запускаем сброс (предполагаем, что tools.flushDNS() делает это)
        tools.flushDNS()
        
        // Имитируем небольшую задержку для UI (или реальное выполнение)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isFlushingDNS = false
                dnsFlushSuccess = true
            }
            
            // Сбрасываем статус "Успех" через 2 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    dnsFlushSuccess = false
                }
            }
        }
    }
}
