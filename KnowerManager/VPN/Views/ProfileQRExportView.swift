import SwiftUI

// MARK: - Показ QR-кода профиля (экспорт в другое устройство/приложение)

struct ProfileQRExportView: View {
    let profile: ShadowsocksProfile
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var link: String?
    @State private var qrImage: NSImage?
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(settings.t(.vpnQrExportTitle))
                    .font(.headline)
                Spacer()
                Button("X") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }

            if let qrImage {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(radius: 3)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary)
                    Text(settings.t(.qrNotGenerated))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(width: 220, height: 220)
            }

            // Имя и протокол
            HStack(spacing: 6) {
                Text(profile.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                ProtocolBadge(text: profile.protocolType.rawValue.uppercased(), color: .blue)
            }

            HStack(spacing: 10) {
                Button {
                    if let link {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(link, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                } label: {
                    Label(copied ? settings.t(.statusCopied) : settings.t(.vpnQrCopyLink),
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(link == nil)

                Button {
                    if let qrImage {
                        QRCodeService.saveAsPNG(qrImage, suggestedName: "\(profile.name).png")
                    }
                } label: {
                    Label(settings.t(.btnSaveImage), systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(qrImage == nil)
            }

            if let link {
                Text(link)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
            }
        }
        .padding(20)
        .frame(width: 330)
        .onAppear(perform: generate)
    }

    private func generate() {
        guard let link = LinkExporter.exportURL(profile) else { return }
        self.link = link
        self.qrImage = QRCodeService.generate(from: link)
    }
}