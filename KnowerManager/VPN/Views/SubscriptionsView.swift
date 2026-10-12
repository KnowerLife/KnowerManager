import SwiftUI

// MARK: - Sheet управления подписками

struct SubscriptionsView: View {
    @ObservedObject var subs = SubscriptionManager.shared
    @ObservedObject var xray = XrayService.shared
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var isAdding = false
    @State private var newName = ""
    @State private var newURL = ""
    @State private var newUA = ""
    @State private var newInterval = 24

    private let intervalOptions = [1, 6, 12, 24, 72, 168]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if subs.subscriptions.isEmpty && !isAdding {
                emptyState
            } else {
                List {
                    ForEach(subs.subscriptions) { sub in
                        SubscriptionRow(
                            subscription: sub,
                            profileCount: profileCount(for: sub.id),
                            isUpdating: subs.pendingCount > 0
                        )
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }

            if isAdding { addForm }

            footer
        }
        .frame(width: 440, height: 460)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath.circle")
                .font(.system(size: 18))
                .foregroundColor(.blue)
            Text(settings.t(.vpnSubscriptions))
                .font(.system(size: 16, weight: .bold))
            Spacer()
            if subs.isUpdatingAll {
                ProgressView().controlSize(.small).scaleEffect(0.7)
            }
            Button {
                subs.updateAll()
            } label: {
                Label(settings.t(.subUpdateAll), systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
            .disabled(subs.subscriptions.isEmpty || subs.isUpdatingAll)

            Button(settings.t(.btnDone)) { dismiss() }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
        }
        .padding(14)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "externaldrive.badge.icloud")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.4))
            Text(settings.t(.subNoSubscriptions))
                .font(.headline)
                .foregroundColor(.secondary)
            Text(settings.t(.subAddHint))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                withAnimation { isAdding.toggle() }
            } label: {
                Label(settings.t(.subAddTitle), systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: Add form

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.t(.subAddTitle)).font(.headline)
            TextField(settings.t(.subName), text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("URL (https://...)", text: $newURL)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
            TextField("User-Agent", text: $newUA)
                .textFieldStyle(.roundedBorder)
            Picker(settings.t(.subInterval), selection: $newInterval) {
                ForEach(intervalOptions, id: \.self) { h in
                    Text(intervalLabel(h)).tag(h)
                }
            }
            .pickerStyle(.menu)
            HStack {
                Button(settings.t(.btnCancel)) {
                    withAnimation { isAdding = false }
                    newName = ""; newURL = ""; newUA = ""
                }
                Spacer()
                Button {
                    addNew()
                } label: {
                    Label(settings.t(.subAddTitle), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(newURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(NSColor.separatorColor)), alignment: .top)
    }

    private func intervalLabel(_ hours: Int) -> String {
        if hours < 24 { return "\(hours) h" }
        if hours == 24 { return "1 day" }
        return "\(hours / 24) days"
    }

    private func addNew() {
        if subs.addSubscription(url: newURL, name: newName, userAgent: newUA.isEmpty ? nil : newUA, updateIntervalHours: newInterval) != nil {
            withAnimation { isAdding = false }
            newName = ""; newURL = ""; newUA = ""
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if let err = subs.lastError, !err.isEmpty {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else {
                Text("\(subs.subscriptions.count) \(settings.t(.vpnProfilesLoaded).lowercased())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !subs.subscriptions.isEmpty {
                Button {
                    withAnimation { isAdding.toggle() }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func profileCount(for id: UUID) -> Int {
        xray.profiles.filter { $0.subscriptionId == id }.count
    }
}

// MARK: - Row

struct SubscriptionRow: View {
    let subscription: VPNSubscription
    let profileCount: Int
    let isUpdating: Bool
    @ObservedObject var subs = SubscriptionManager.shared
    @ObservedObject var settings = SettingsManager.shared

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(subscription.isEnabled ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(subscription.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if profileCount > 0 {
                        Text("(\(profileCount))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Text(subscription.url)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                trafficBar
                statusLine
            }

            Spacer()

            VStack(spacing: 6) {
                Menu {
                    Button {
                        SubscriptionManager.shared.update(subscriptionId: subscription.id)
                    } label: {
                        Label(settings.t(.subUpdateNow), systemImage: "arrow.clockwise")
                    }
                    Button {
                        SubscriptionManager.shared.toggleEnabled(id: subscription.id)
                    } label: {
                        Label(
                            subscription.isEnabled ? settings.t(.subDisable) : settings.t(.subEnable),
                            systemImage: subscription.isEnabled ? "pause.circle" : "play.circle"
                        )
                    }
                    Divider()
                    Button(role: .destructive) {
                        SubscriptionManager.shared.removeSubscription(id: subscription.id)
                    } label: {
                        Label(settings.t(.subDelete), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: isUpdating ? "arrow.triangle.2.circlepath" : "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundColor(isUpdating ? .blue : .secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 22, height: 22)
            }
        }
        .padding(.vertical, 6)
        .background(subscription.isEnabled ? Color.clear : Color.gray.opacity(0.08))
    }

    @ViewBuilder
    private var trafficBar: some View {
        if let t = subscription.traffic, t.hasQuota {
            HStack(spacing: 6) {
                ProgressView(value: t.usagePercent)
                    .progressViewStyle(.linear)
                    .scaleEffect(y: 0.6)
                Text("\(Int(t.usagePercent * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(t.usagePercent > 0.85 ? .red : .secondary)
            }
            Text("\(Self.byteString(t.usedBytes)) / \(Self.byteString(t.totalBytes)) \(settings.t(.subUsed))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: 10) {
            if let expire = subscription.traffic?.expiryDate {
                Label(
                    expire > Date() ? "\(settings.t(.subExpires)) \(Self.dateFormatter.string(from: expire))" : settings.t(.subExpired),
                    systemImage: "calendar"
                )
                .foregroundColor(expire > Date() ? .secondary : .red)
            }
            if let last = subscription.lastUpdate {
                Label(
                    "\(settings.t(.subLastUpdate)) \(Self.relativeString(last))",
                    systemImage: "clock"
                )
                .foregroundColor(.secondary)
            } else {
                Text(settings.t(.subNeverUpdated))
                    .foregroundColor(.orange)
            }
        }
        .font(.system(size: 9))
        .lineLimit(1)
    }

    private static func byteString(_ v: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: v, countStyle: .binary)
    }

    private static func relativeString(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}