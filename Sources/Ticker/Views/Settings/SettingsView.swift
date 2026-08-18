import SwiftUI

struct SettingsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case general, wellness, categories
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "General"
            case .wellness: return "Wellness"
            case .categories: return "App Categories"
            }
        }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .wellness: return "heart.text.square"
            case .categories: return "square.grid.2x2"
            }
        }
    }

    @State private var tab: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 540, height: 500)
    }

    // Equal-width tab blocks (each takes a 1/N share of the row).
    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases) { tabButton($0) }
        }
        .padding(10)
    }

    private func tabButton(_ item: Tab) -> some View {
        let selected = tab == item
        return Button {
            tab = item
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.symbol).font(.system(size: 16, weight: .medium))
                Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? Color.accentColor.opacity(0.15) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .general: GeneralSettings()
        case .wellness: WellnessSettings()
        case .categories: CategorySettings()
        }
    }
}

struct GeneralSettings: View {
    @EnvironmentObject var store: TickerStore
    @EnvironmentObject var tracker: Tracker
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch Ticker at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        if !LoginItem.set(enabled) {
                            launchAtLogin = LoginItem.isEnabled  // revert on failure
                        }
                    }
                Toggle("Notify me when I reach my focus goal", isOn: Binding(
                    get: { store.notifyOnGoal },
                    set: { on in
                        store.notifyOnGoal = on
                        if on { Notifier.requestAuthorization() }
                    }
                ))
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: tracker.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(tracker.accessibilityGranted ? .green : .orange)
                    VStack(alignment: .leading) {
                        Text("Accessibility Access")
                        Text(tracker.accessibilityGranted
                             ? "Keyboard activity tracking is enabled."
                             : "Needed to count keystrokes. App & idle tracking work without it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !tracker.accessibilityGranted {
                        Button("Open Settings") {
                            Permissions.requestAccessibility()
                            Permissions.openAccessibilitySettings()
                        }
                    }
                }
            }

            Section("Focus Goal") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Daily productive-time goal")
                        Spacer()
                        Text(Format.compactDuration(store.dailyGoalMinutes * 60))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(store.dailyGoalMinutes) },
                        set: { store.dailyGoalMinutes = Int($0) }
                    ), in: 30...600, step: 15)
                    Text("Shown as a progress ring on the dashboard. Week/month scale it by the number of days.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text("Weekly total-hours goal")
                        Spacer()
                        Text("\(store.weeklyGoalHours)h")
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { Double(store.weeklyGoalHours) },
                        set: { store.weeklyGoalHours = Int($0) }
                    ), in: 5...80, step: 1)
                    Text("Total tracked hours this week, shown as the Weekly Hours bar on the dashboard. Default 40h.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Idle Detection") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Mark as idle after")
                        Spacer()
                        Text("\(store.idleThreshold)s").foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(store.idleThreshold) },
                        set: { store.idleThreshold = Int($0) }
                    ), in: 30...300, step: 15)
                    Text("Time without keyboard or mouse input before a moment counts as idle.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Screen Timeline (optional)") {
                Toggle("Capture screenshots of my screen", isOn: Binding(
                    get: { store.captureScreenshots },
                    set: { on in
                        store.captureScreenshots = on
                        if on { ScreenshotService.shared.requestAuthorization() }
                    }
                ))
                if store.captureScreenshots {
                    Picker("Capture every", selection: Binding(
                        get: { store.captureIntervalMinutes },
                        set: { store.captureIntervalMinutes = $0 }
                    )) {
                        Text("1 minute").tag(1)
                        Text("2 minutes").tag(2)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                    }
                    Picker("Delete screenshots after", selection: Binding(
                        get: { store.screenshotRetentionDays },
                        set: { store.screenshotRetentionDays = $0 }
                    )) {
                        Text("1 day").tag(1)
                        Text("2 days").tag(2)
                        Text("3 days").tag(3)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: Permissions.isScreenRecordingGranted
                              ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(Permissions.isScreenRecordingGranted ? .green : .orange)
                        Text(Permissions.isScreenRecordingGranted
                             ? "Screen Recording is enabled."
                             : "Approve the prompt, or enable Ticker under System Settings → Privacy & Security → Screen & System Audio Recording — then quit and reopen Ticker.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    Button("Request access / open settings") {
                        ScreenshotService.shared.requestAuthorization()
                        Permissions.openScreenRecordingSettings()
                    }
                }
                Text("Saves a small thumbnail of your screen on the interval above while you're active — kept only on this Mac and auto-deleted on the schedule above. Capture starts once you grant permission and reopen Ticker. Shown as the Screen Timeline on the dashboard's Day view.")
                    .font(.caption).foregroundStyle(.secondary)
                Button(role: .destructive) {
                    store.clearScreenshots()
                } label: {
                    Label("Delete all screenshots", systemImage: "trash")
                }
            }

            Section("Privacy") {
                Label("Ticker records the active app and its window title (e.g. browser tab or project) and counts how many keys/clicks you make — never which keys or what you type. Screenshots are off unless you turn on the Screen Timeline above. Everything stays on this Mac.",
                      systemImage: "hand.raised.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear all tracked data", systemImage: "trash")
                }
                .confirmationDialog("Delete all tracked history? This can't be undone.",
                                    isPresented: $showClearConfirm, titleVisibility: .visible) {
                    Button("Delete Everything", role: .destructive) { store.clearAllData() }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct WellnessSettings: View {
    @EnvironmentObject var store: TickerStore

    var body: some View {
        Form {
            Section("Break reminders") {
                Toggle("Remind me to take breaks", isOn: Binding(
                    get: { store.breakRemindersEnabled },
                    set: { on in
                        store.breakRemindersEnabled = on
                        if on { Notifier.requestAuthorization() }
                    }
                ))
                Picker("Stand & move break", selection: Binding(
                    get: { store.moveBreakMinutes }, set: { store.moveBreakMinutes = $0 })) {
                    Text("Every 15 min").tag(15)
                    Text("Every 20 min").tag(20)
                    Text("Every 30 min").tag(30)
                    Text("Every 45 min").tag(45)
                    Text("Every 60 min").tag(60)
                }
                .disabled(!store.breakRemindersEnabled)
                Picker("Screen / eye break", selection: Binding(
                    get: { store.screenBreakMinutes }, set: { store.screenBreakMinutes = $0 })) {
                    Text("Every 30 min").tag(30)
                    Text("Every 45 min").tag(45)
                    Text("Every 60 min").tag(60)
                    Text("Every 90 min").tag(90)
                    Text("Every 2 hours").tag(120)
                }
                .disabled(!store.breakRemindersEnabled)
                Picker("Move break length", selection: Binding(
                    get: { store.moveBreakDurationMinutes }, set: { store.moveBreakDurationMinutes = $0 })) {
                    Text("1 minute").tag(1)
                    Text("2 minutes").tag(2)
                    Text("3 minutes").tag(3)
                    Text("5 minutes").tag(5)
                }
                .disabled(!store.breakRemindersEnabled)
                Picker("Screen break length", selection: Binding(
                    get: { store.screenBreakDurationMinutes }, set: { store.screenBreakDurationMinutes = $0 })) {
                    Text("3 minutes").tag(3)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }
                .disabled(!store.breakRemindersEnabled)
                Picker("Minimum time between breaks", selection: Binding(
                    get: { store.minBreakGapMinutes }, set: { store.minBreakGapMinutes = $0 })) {
                    Text("No minimum").tag(0)
                    Text("15 min").tag(15)
                    Text("20 min").tag(20)
                    Text("30 min").tag(30)
                    Text("45 min").tag(45)
                }
                .disabled(!store.breakRemindersEnabled)
                Toggle("Show the reminder over all apps", isOn: Binding(
                    get: { store.breakOverlayAllScreens },
                    set: { store.breakOverlayAllScreens = $0 }))
                    .disabled(!store.breakRemindersEnabled)
                Text("Move breaks are 1–2 minutes; screen breaks are 5–10 minutes. Timers count only active time and pause when you step away — a long enough break counts as taken. With “over all apps” off, the reminder appears only inside Ticker.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Ergonomics") {
                ForEach(Wellness.ergonomics, id: \.self) { tip in
                    Label(tip, systemImage: "checkmark.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.callout)
                        .padding(.vertical, 1)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct CategorySettings: View {
    @EnvironmentObject var store: TickerStore
    @State private var search = ""

    private var apps: [AppTotal] {
        let all = store.knownApps()
        guard !search.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search apps", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 9))
            .padding(12)

            if apps.isEmpty {
                Spacer()
                Text("No apps tracked yet.\nUse your Mac for a bit and they'll appear here.")
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(apps) { app in
                        HStack {
                            AppIconView(bundleId: app.bundleId, size: 20, fallbackTint: app.category.color)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name).lineLimit(1)
                                Text(Format.duration(app.seconds) + " total")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("", selection: Binding(
                                get: { app.category },
                                set: { store.setCategory($0, for: app.bundleId) }
                            )) {
                                ForEach(AppCategory.allCases) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
