import SwiftUI

struct AboutView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        ZStack {
            // 1. Единый фон (Адаптируется под тему)
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // --- HEADER ---
                VStack(spacing: 16) {
                    ZStack {
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 128, height: 128)
                    }
                    
                    VStack(spacing: 6) {
                        Text(settings.t(.appTitle))
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .tracking(1.5)

                        
                        Text(settings.t(.aboutVersion))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 30)
                .padding(.bottom, 20)
                
                Divider()
                    .background(DesignSystem.strokeColor)
                
                // --- SCROLLABLE CONTENT (FAQ) ---
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        
                        // Список FAQ (Полный функционал)
                        VStack(spacing: 12) {
                            
                            // 1. VPN & Deep Scan (НОВОЕ - Самое важное)
                            FAQRow(icon: "lock.shield.fill", color: .purple, question: settings.t(.faqVpnQ), answer: settings.t(.faqVpnA))
                            FAQRow(icon: "bolt.horizontal.fill", color: .orange, question: settings.t(.faqDeepScanQ), answer: settings.t(.faqDeepScanA))
                            
                            // 2. Стратегии и Авто-подбор
                            FAQRow(icon: "wand.and.stars", color: .blue, question: settings.t(.faqWandQ), answer: settings.t(.faqWandA))
                            
                            // 3. WARP
                            FAQRow(icon: "key.fill", color: .cyan, question: settings.t(.faqWarpQ), answer: settings.t(.faqWarpA))
                            
                            // 4. Инструменты
                            FAQRow(icon: "wrench.and.screwdriver.fill", color: .gray, question: settings.t(.faqToolsQ), answer: settings.t(.faqToolsA))
                            
                            // 5. OCR & AI
                            FAQRow(icon: "text.viewfinder", color: .pink, question: settings.t(.faqOcrQ), answer: settings.t(.faqOcrA))
                            FAQRow(icon: "brain.head.profile", color: .indigo, question: settings.t(.faqAiQ), answer: settings.t(.faqAiA))
                            
                            // 6. Маршрутизация
                            FAQRow(icon: "globe", color: .green, question: settings.t(.faqRouteQ), answer: settings.t(.faqRouteA))
                            
                            // 7. Фиксы
                            FAQRow(icon: "hammer.fill", color: .red, question: settings.t(.faqFixQ), answer: settings.t(.faqFixA))
                            
                            // 8. Gateway & Watch
                            FAQRow(icon: "wifi", color: .mint, question: settings.t(.faqGatewayQ), answer: settings.t(.faqGatewayA))
                            FAQRow(icon: "eye.fill", color: .teal, question: settings.t(.faqKwQ), answer: settings.t(.faqKwA))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .padding(.top, 20)
                    }
                }
                
                // --- FOOTER ---
                VStack(spacing: 0) {
                    Divider()
                        .background(DesignSystem.strokeColor)
                    
                    VStack(spacing: 4) {
                        Text(settings.t(.aboutPowered))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))
                        Text(settings.t(.aboutCopyright))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 50)
                }
                .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            }
        }
        .frame(width: 460, height: 700) // Увеличил размер окна для комфортного чтения
        .preferredColorScheme(settings.currentTheme == .dark ? .dark : (settings.currentTheme == .light ? .light : nil))
    }
}

// --- КОМПОНЕНТ СТРОКИ FAQ ---
struct FAQRow: View {
    let icon: String
    let color: Color
    let question: String
    let answer: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Иконка
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            .padding(.top, 2)
            
            // Текст
            VStack(alignment: .leading, spacing: 4) {
                Text(question)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(answer)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.cardColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.strokeColor, lineWidth: 1)
        )
    }
}
