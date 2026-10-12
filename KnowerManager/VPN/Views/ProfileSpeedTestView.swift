import SwiftUI

// MARK: - Лист реального теста профиля (задержка + скорость через прокси)

struct ProfileSpeedTestView: View {
    let profile: ShadowsocksProfile
    @StateObject private var tester = ProfileProxyTester.shared
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(settings.t(.proxyTestTitle))
                    .font(.headline)
                Spacer()
                Button("X") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }

            // Профиль
            HStack(spacing: 6) {
                Text(profile.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                ProtocolBadge(text: profile.protocolType.rawValue.uppercased(), color: .blue)
            }

            // Результаты
            HStack(spacing: 12) {
                resultCard(
                    title: settings.t(.proxyTestLatency),
                    value: tester.latencyMs.map { "\($0) ms" } ?? "—",
                    icon: "bolt.fill",
                    color: latencyColor
                )
                resultCard(
                    title: settings.t(.proxyTestSpeed),
                    value: tester.downloadMbps.map { String(format: "%.1f Мбит/с", $0) } ?? "—",
                    icon: "arrow.down.circle.fill",
                    color: .blue
                )
            }

            // Статус
            Group {
                if let error = tester.errorText {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundColor(.red)
                } else if let status = tester.statusText {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(status)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                } else if tester.latencyMs != nil || tester.downloadMbps != nil {
                    Text("✓")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 10) {
                Button {
                    tester.runTest(profile: profile)
                } label: {
                    Label(settings.t(.proxyTestRun), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(tester.isTesting)

                if tester.isTesting {
                    Button {
                        tester.cancel()
                    } label: {
                        Label(settings.t(.btnStop), systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(20)
        .frame(width: 340)
        .onDisappear { tester.cancel() }
    }

    private func resultCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }

    private var latencyColor: Color {
        guard let ms = tester.latencyMs else { return .gray }
        if ms < 150 { return .green }
        if ms < 300 { return .orange }
        return .red
    }
}