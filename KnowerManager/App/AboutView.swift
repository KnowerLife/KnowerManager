import SwiftUI

struct AboutView: View {
    @ObservedObject var settings = SettingsManager.shared
    
    private var bundleVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }
    
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

                        
                        Text("\(settings.t(.aboutVersion)) \(bundleVersion)")
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
                
                // --- SCROLLABLE CONTENT (ОПИСАНИЕ + ВОЗМОЖНОСТИ) ---
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        
                        // Описание программы
                        VStack(alignment: .leading, spacing: 8) {
                            Text(settings.t(.aboutTagline))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(settings.t(.aboutIntro))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.cardColor)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(DesignSystem.strokeColor, lineWidth: 1)
                        )
                        
                        // Возможности по модулям
                        VStack(spacing: 12) {
                            // 1. VPN & Deep Scan
                            FAQRow(icon: "lock.shield.fill", color: .purple, question: settings.t(.faqVpnQ), answer: settings.t(.faqVpnA))
                            FAQRow(icon: "bolt.horizontal.fill", color: .orange, question: settings.t(.faqDeepScanQ), answer: settings.t(.faqDeepScanA))
                            
                            // 2. OCR & AI
                            FAQRow(icon: "text.viewfinder", color: .pink, question: settings.t(.faqOcrQ), answer: settings.t(.faqOcrA))
                            FAQRow(icon: "brain.head.profile", color: .indigo, question: settings.t(.faqAiQ), answer: settings.t(.faqAiA))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
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
        .frame(width: 460, height: 700)
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
