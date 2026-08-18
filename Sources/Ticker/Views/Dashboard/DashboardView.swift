import SwiftUI
import Charts
import AppKit

/// Top-level sections of the dashboard, shown in the sidebar.
enum DashboardSection: String, CaseIterable, Identifiable {
    case overview, insights, apps, timeline
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .insights: return "Insights"
        case .apps: return "Apps"
        case .timeline: return "Timeline"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .insights: return "lightbulb.fill"
        case .apps: return "app.badge.fill"
        case .timeline: return "calendar.day.timeline.left"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: DashboardViewModel
    @EnvironmentObject private var breaks: BreakManager

    @State private var showCalendar = false
    @State private var viewerIndex = 0
    @State private var showViewer = false
    @State private var section: DashboardSection = .overview

    private let brand = LinearGradient(
        colors: [Color(red: 0.36, green: 0.31, blue: 0.92), Color(red: 0.10, green: 0.71, blue: 0.82)],
        startPoint: .leading, endPoint: .trailing)

    // Ticks while running; the model decides whether a refresh is actually due.
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Thin forwarders so the section views read from the view model.
    private var scope: Timescale { model.scope }
    private var anchor: Date { model.anchor }
    private var interval: DateInterval { model.interval }
    private var isCurrentPeriod: Bool { model.isCurrentPeriod }
    private var snapshot: DashboardSnapshot { model.snapshot }
    private var summary: DaySummary { model.snapshot.summary }
    private var goalSeconds: Int { model.goalSeconds }
    private var goalProgress: Double { model.goalProgress }
    private var focusedSeconds: Int { model.snapshot.focusedSeconds }
    private var weeklyActiveSeconds: Int { model.snapshot.weeklyActiveSeconds }
    private var weeklyGoalSeconds: Int { model.snapshot.weeklyGoalHours * 3600 }
    private var weeklyGoalProgress: Double {
        weeklyGoalSeconds > 0 ? min(1, Double(weeklyActiveSeconds) / Double(weeklyGoalSeconds)) : 0
    }
    private var lastRefreshed: Date { model.lastRefreshed }
    private var accessibilityOK: Bool { model.accessibilityGranted }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            VStack(spacing: 0) {
                detailTopBar
                Divider()
                ScrollView {
                    sectionContent
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(WindowBackground())
            }
        }
        .overlay {
            // In-app overlay only when the system-wide floating overlay is off.
            if let kind = breaks.pending, !breaks.overlayAllScreens {
                BreakOverlayView(kind: kind,
                                 intervalMinutes: breaks.intervalMinutes(kind),
                                 breakSeconds: breaks.breakDurationSeconds(kind),
                                 onComplete: { breaks.take(kind) },
                                 onSnooze: { breaks.snooze(kind) })
            }
        }
        .animation(.easeInOut(duration: 0.2), value: breaks.pending)
        .navigationTitle("Ticker")
        .sheet(isPresented: $showViewer) {
            ScreenshotViewer(shots: snapshot.shots, index: $viewerIndex) { model.deleteScreenshot($0) }
        }
        .onAppear { model.onAppear() }
        .onReceive(refreshTimer) { _ in model.tick() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.appBecameActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            model.appResignedActive()
        }
    }

    // MARK: Navigation shell

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(brand)
                Text("Ticker").font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 14).padding(.top, 16).padding(.bottom, 8)
            LiveStatusView()
                .padding(.horizontal, 14).padding(.bottom, 10)
            SidebarBreaksView()
                .padding(.horizontal, 14).padding(.bottom, 12)
            Divider()
            List(selection: $section) {
                ForEach(DashboardSection.allCases) { s in
                    Label(s.title, systemImage: s.symbol).tag(s)
                }
            }
            .listStyle(.sidebar)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 216, max: 260)
    }

    private var detailTopBar: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title).font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                toolbarActions
            }
            controls
            if !accessibilityOK { permissionBanner }
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
    }

    private var toolbarActions: some View {
        HStack(spacing: 10) {
            TrackingToggle()
            VStack(alignment: .trailing, spacing: 1) {
                Text("Updated \(lastRefreshed, format: .dateTime.hour().minute())")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Text("auto every 5 min").font(.system(size: 9)).foregroundStyle(.tertiary)
            }
            Button(action: model.rebuild) { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.bordered).help("Refresh now")
            Menu {
                Button { model.exportWeeklyPDF() } label: { Label("Weekly report (PDF)", systemImage: "doc.richtext") }
                Button { model.exportMonthlyPDF() } label: { Label("Monthly report (PDF)", systemImage: "doc.richtext") }
                Divider()
                Button { model.exportCSV() } label: { Label("All data (CSV)", systemImage: "tablecells") }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton).fixedSize()
        }
    }

    @ViewBuilder private var sectionContent: some View {
        switch section {
        case .overview:
            VStack(alignment: .leading, spacing: 18) {
                statsRow
                HStack(spacing: 18) {
                    goalCard.frame(width: 280)
                    activityCard
                    trendCard
                }
                .frame(height: 290)
                weeklyGoalCard
            }
        case .insights:
            VStack(alignment: .leading, spacing: 18) {
                insightsStrip
                HStack(spacing: 18) {
                    peakHoursCard
                    recapCard
                }
                .frame(height: 250)
            }
        case .apps:
            categoryColumnsCard
        case .timeline:
            VStack(alignment: .leading, spacing: 18) {
                if scope == .day {
                    minuteTimelineCard
                    activityBlocksCard
                } else {
                    emptyState("Switch to Day view to see the minute timeline and per-minute activity blocks.")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
        }
    }

    // MARK: Scope + calendar controls

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("", selection: $model.scope) {
                ForEach(Timescale.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()                       // natural width, no centering slop
            .frame(maxWidth: 260, alignment: .leading)

            Spacer()

            periodNavigator
        }
        .controlSize(.large)   // same size for both clusters -> equal heights
    }

    private var periodNavigator: some View {
        HStack(spacing: 6) {
            Button { model.shift(-1) } label: {
                Image(systemName: "chevron.left")
            }

            Button {
                showCalendar = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                    Text(rangeLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(minWidth: 130)
                }
            }
            .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
                calendarPopover
            }

            Button { model.shift(1) } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentPeriod)

            Button("Today") { model.goToToday() }
                .disabled(isCurrentPeriod)
        }
        .buttonStyle(.bordered)
    }

    private var calendarPopover: some View {
        CalendarPicker(
            selection: $model.anchor,
            daysWithData: model.daysWithData,
            weekHighlight: scope == .week ? interval : nil,
            footnote: calendarFootnote,
            onPick: { showCalendar = false }
        )
        .frame(width: 296)
    }

    private var calendarFootnote: String? {
        switch scope {
        case .day: return nil
        case .week: return "Jumps to the week of the day you pick"
        case .month: return "Jumps to the month of the day you pick"
        }
    }

    private var rangeLabel: String {
        let cal = Calendar.current
        switch scope {
        case .day:
            if cal.isDateInToday(anchor) { return "Today" }
            if cal.isDateInYesterday(anchor) { return "Yesterday" }
            return anchor.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .week:
            let end = cal.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
            let endStr = end.formatted(.dateTime.month(.abbreviated).day())
            return "\(start) – \(endStr)"
        case .month:
            return interval.start.formatted(.dateTime.month(.wide).year())
        }
    }

    // MARK: Permission banner

    private var permissionBanner: some View {
        Card(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Accessibility to track keyboard activity")
                        .font(.system(size: 13, weight: .semibold))
                    Text("App usage and idle time already work. Grant access to count keystrokes for the activity graph.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Grant Access") {
                    Permissions.requestAccessibility()
                    Permissions.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 14) {
            StatTile(title: "Active Time",
                     value: Format.compactDuration(summary.activeSeconds),
                     subtitle: activeSubtitle,
                     symbol: "clock.fill", tint: .cyan)
            StatTile(title: "Productive",
                     value: Format.compactDuration(summary.productiveSeconds),
                     subtitle: "in productive apps",
                     symbol: "checkmark.seal.fill", tint: AppCategory.productive.color)
            StatTile(title: "Productivity",
                     value: Format.percent(summary.productivity),
                     subtitle: "of active time",
                     symbol: "chart.line.uptrend.xyaxis", tint: .purple)
            StatTile(title: "Interactions",
                     value: "\(summary.keyCount + summary.mouseCount)",
                     subtitle: "\(summary.keyCount) keys · \(summary.mouseCount) clicks",
                     symbol: "hand.tap.fill", tint: .pink)
        }
    }

    private var activeSubtitle: String {
        switch scope {
        case .day: return "tracked engagement"
        case .week: return "this week"
        case .month: return "this month"
        }
    }

    // MARK: Activity graph

    private var activityCard: some View {
        Card(fill: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(text: activityTitle, symbol: "waveform.path.ecg")
                if scope == .day {
                    if summary.keyCount + summary.mouseCount == 0 {
                        emptyState("No interactions recorded yet").frame(maxHeight: .infinity)
                    } else {
                        ActivityChart(buckets: snapshot.dayBuckets)
                            .frame(maxHeight: .infinity)
                    }
                } else {
                    if summary.activeSeconds == 0 {
                        emptyState("No activity in this period yet").frame(maxHeight: .infinity)
                    } else {
                        RangeBarChart(breakdowns: snapshot.breakdowns, scope: scope)
                            .frame(maxHeight: .infinity)
                        rangeChartLegend
                    }
                }
            }
        }
    }

    private var activityTitle: String {
        switch scope {
        case .day: return "Activity Over the Day"
        case .week: return "Focus by Day · This Week"
        case .month: return "Focus by Day · This Month"
        }
    }

    private var rangeChartLegend: some View {
        HStack(spacing: 16) {
            ForEach(AppCategory.allCases) { cat in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(cat.color).frame(width: 10, height: 10)
                    Text(cat.title).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Focus goal

    private var goalCard: some View {
        Card(fill: true) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Focus Goal", symbol: "target")
                Spacer(minLength: 4)
                HStack { Spacer(); GoalRing(progress: goalProgress).frame(width: 92, height: 92); Spacer() }
                Spacer(minLength: 4)
                VStack(spacing: 0) {
                    goalRow("Focused", Format.compactDuration(focusedSeconds))
                    Divider()
                    goalRow("Goal", Format.compactDuration(goalSeconds))
                    Divider()
                    if goalProgress >= 1 {
                        goalRow("Status", "Reached", tint: AppCategory.productive.color)
                    } else {
                        goalRow("Remaining", Format.compactDuration(max(0, goalSeconds - focusedSeconds)))
                    }
                }
            }
        }
    }

    // MARK: Weekly hours goal

    private var weeklyGoalCard: some View {
        let tint = Color(red: 0.36, green: 0.31, blue: 0.92)
        let remaining = max(0, weeklyGoalSeconds - weeklyActiveSeconds)
        return Card(fill: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    SectionTitle(text: "Weekly Hours", symbol: "calendar")
                    Spacer()
                    Text("\(Format.compactDuration(weeklyActiveSeconds)) / \(Format.compactDuration(weeklyGoalSeconds))")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(Format.percent(weeklyGoalProgress))
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
                MiniBar(fraction: weeklyGoalProgress, color: tint)
                Text(weeklyGoalProgress >= 1
                     ? "Weekly goal reached 🎉"
                     : "\(Format.compactDuration(remaining)) to reach your \(snapshot.weeklyGoalHours)h weekly goal · change in Settings → General")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private func goalRow(_ label: String, _ value: String, tint: Color? = nil) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(tint ?? .primary)
        }
        .padding(.vertical, 7)
    }

    private var goalSubtitle: String {
        let perDay = Format.compactDuration(snapshot.dailyGoalMinutes * 60)
        switch scope {
        case .day: return "target: \(perDay) of continuous focus today (gaps over 10 min break it)"
        default: return "target: \(perDay)/day × \(snapshot.goalDays) day\(snapshot.goalDays == 1 ? "" : "s")"
        }
    }

    // MARK: Insights

    private var focusSessions: [Int] { snapshot.sessions }
    private var hourStats: [HourStat] { snapshot.hourStats }
    private var peakHour: HourStat? {
        hourStats.filter { $0.activeSeconds > 0 }.max { $0.activeSeconds < $1.activeSeconds }
    }
    private var streak: Int { snapshot.streak }

    private var insightsStrip: some View {
        HStack(spacing: 14) {
            StatTile(title: "Focus Streak",
                     value: "\(streak)",
                     subtitle: streak == 1 ? "day meeting goal" : "days meeting goal",
                     symbol: "flame.fill", tint: .orange)
            StatTile(title: "Deep Work",
                     value: "\(focusSessions.filter { $0 >= 25 * 60 }.count)",
                     subtitle: "25 min+ focus blocks",
                     symbol: "brain.head.profile", tint: AppCategory.productive.color)
            StatTile(title: "Longest Focus",
                     value: Format.compactDuration(focusSessions.max() ?? 0),
                     subtitle: "deepest session",
                     symbol: "timer", tint: .purple)
            StatTile(title: "Context Switches",
                     value: "\(snapshot.contextSwitches)",
                     subtitle: "app switches",
                     symbol: "arrow.left.arrow.right", tint: .pink)
        }
    }

    private var peakHoursCard: some View {
        Card(fill: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle(text: "Peak Hours", symbol: "sun.max.fill")
                    Spacer()
                    if let peak = peakHour {
                        Text("Most active around \(Format.hourLabel(peak.hour))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                if hourStats.allSatisfy({ $0.activeSeconds == 0 }) {
                    emptyState("No hourly activity yet").frame(maxHeight: .infinity)
                } else {
                    HourBarChart(stats: hourStats, peakHour: peakHour?.hour)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: Weekly recap

    private var recapCard: some View {
        let recap = snapshot.recap
        return Card(fill: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(text: "Weekly Recap", symbol: "sparkles")
                if !recap.hasData {
                    emptyState("Your weekly digest appears after a few days of tracking")
                        .frame(maxHeight: .infinity)
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Format.duration(recap.productiveSeconds))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("productive · last 7 days")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        deltaChip(recap)
                    }
                    Divider()
                    HStack(spacing: 24) {
                        recapStat("Best day",
                                  recap.bestDay.map { $0.formatted(.dateTime.weekday(.wide)) } ?? "—",
                                  recap.bestDay != nil ? Format.duration(recap.bestDaySeconds) : "")
                        recapStat("Top app",
                                  recap.topApp ?? "—",
                                  recap.topApp != nil ? Format.duration(recap.topAppSeconds) : "")
                        recapStat("Avg productivity", Format.percent(recap.avgProductivity), "of active time")
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func deltaChip(_ recap: WeeklyRecap) -> some View {
        let up = recap.deltaFraction >= 0
        let isNew = recap.previousProductiveSeconds == 0
        let text = isNew ? "new" : "\(up ? "+" : "")\(Int((recap.deltaFraction * 100).rounded()))%"
        let color = up ? AppCategory.productive.color : AppCategory.distracting.color
        return HStack(spacing: 5) {
            if !isNew { Image(systemName: up ? "arrow.up.right" : "arrow.down.right") }
            Text(text)
            Text("vs last week").foregroundStyle(.secondary).font(.system(size: 11))
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(isNew ? Color.secondary : color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background((isNew ? Color.secondary : color).opacity(0.14), in: Capsule())
    }

    private func recapStat(_ label: String, _ value: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(value).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            if !sub.isEmpty {
                Text(sub).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Productivity trend

    private var trendPoints: [ProductivityPoint] { snapshot.trend }

    private var trendCard: some View {
        Card(fill: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(text: scope == .day ? "Productivity Trend · Last 14 Days" : "Productivity Trend",
                             symbol: "chart.xyaxis.line")
                if trendPoints.allSatisfy({ $0.activeSeconds == 0 }) {
                    emptyState("Not enough data for a trend yet").frame(maxHeight: .infinity)
                } else {
                    ProductivityTrendChart(points: trendPoints)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: Minute timeline

    private var minuteTimelineCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "Minute Timeline", symbol: "calendar.day.timeline.left")
                    Spacer()
                    timelineLegend
                }
                if snapshot.minuteCells.allSatisfy({ !$0.active }) {
                    emptyState("No activity recorded for this day yet").frame(height: 60)
                } else {
                    MinuteTimelineStrip(cells: snapshot.minuteCells)
                        .frame(height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    HStack {
                        Text("12 AM"); Spacer(); Text("6 AM"); Spacer()
                        Text("12 PM"); Spacer(); Text("6 PM"); Spacer(); Text("12 AM")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var timelineLegend: some View {
        HStack(spacing: 12) {
            ForEach(AppCategory.allCases) { cat in
                legendSwatch(cat.color, cat.title)
            }
            legendSwatch(Color.secondary.opacity(0.25), "Idle")
        }
    }

    private func legendSwatch(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    // MARK: Activity blocks (10-minute windows)

    private var activityBlocksCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle(text: "Activity Blocks", symbol: "square.stack.3d.up.fill")
                    Spacer()
                    Text("10-min blocks · tap for detail")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                if !snapshot.captureEnabled {
                    captureHint
                }
                if snapshot.blocks.isEmpty {
                    emptyState("No activity recorded for this day yet").frame(height: 80)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                        ForEach(snapshot.blocks.prefix(120)) { block in
                            ActivityBlockTile(
                                block: block,
                                captureEnabled: snapshot.captureEnabled,
                                onOpenShot: { openViewer(for: $0) },
                                onDeleteShots: { model.deleteBlockScreenshots(block) })
                        }
                    }
                    if snapshot.blocks.count > 120 {
                        Text("Showing the most recent 120 blocks.")
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var captureHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.metering.none").foregroundStyle(.secondary)
            Text("Screenshots are off — enable the Screen Timeline in Settings to see the screen for each block.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }

    private func openViewer(for url: URL) {
        if let idx = snapshot.shots.firstIndex(where: { $0.url == url }) {
            viewerIndex = idx
            showViewer = true
        }
    }

    // MARK: Category breakdown

    private var categoryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(text: "Focus Split", symbol: "chart.pie.fill")
                if summary.activeSeconds == 0 {
                    emptyState("No activity yet").frame(height: 220)
                } else {
                    CategoryDonut(summary: summary)
                        .frame(height: 150)
                    categoryLegend
                }
            }
        }
    }

    private var categoryLegend: some View {
        VStack(spacing: 10) {
            legendRow(.productive, summary.productiveSeconds)
            legendRow(.neutral, summary.neutralSeconds)
            legendRow(.distracting, summary.distractingSeconds)
        }
    }

    private func legendRow(_ cat: AppCategory, _ seconds: Int) -> some View {
        let frac = summary.activeSeconds > 0 ? Double(seconds) / Double(summary.activeSeconds) : 0
        return VStack(spacing: 4) {
            HStack {
                Circle().fill(cat.color).frame(width: 8, height: 8)
                Text(cat.title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(Format.duration(seconds)).font(.system(size: 12)).foregroundStyle(.secondary)
                Text(Format.percent(frac)).font(.system(size: 11)).foregroundStyle(.tertiary)
                    .frame(width: 38, alignment: .trailing)
            }
            MiniBar(fraction: frac, color: cat.color)
        }
    }

    // MARK: Top apps

    private var topAppsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(text: "Top Apps", symbol: "app.badge.fill")
                if summary.apps.isEmpty {
                    emptyState("No apps tracked yet").frame(height: 220)
                } else {
                    VStack(spacing: 12) {
                        ForEach(summary.apps.prefix(8)) { app in
                            appRow(app)
                        }
                    }
                }
            }
        }
    }

    private func appRow(_ app: AppTotal) -> some View {
        let frac = summary.activeSeconds > 0 ? Double(app.seconds) / Double(summary.activeSeconds) : 0
        return VStack(spacing: 5) {
            HStack(spacing: 8) {
                AppIconView(bundleId: app.bundleId, size: 18, fallbackTint: app.category.color)
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Image(systemName: app.category.symbol)
                    .font(.system(size: 9))
                    .foregroundStyle(app.category.color)
                Spacer()
                Text(Format.duration(app.seconds))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            MiniBar(fraction: frac, color: app.category.color)
        }
    }

    // MARK: Category columns (by-category app breakdown)

    private var categoryColumnsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle(text: "Where your time went", symbol: "rectangle.3.group.fill")
                    Spacer()
                    Text("Drag an app between columns — drop it in Excluded to stop tracking it")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                HStack(alignment: .top, spacing: 14) {
                    CategoryColumnView(category: .productive, total: summary.productiveSeconds,
                                       apps: summary.apps.filter { $0.category == .productive },
                                       onDropApp: { model.moveApp($0, to: .productive) })
                    CategoryColumnView(category: .neutral, total: summary.neutralSeconds,
                                       apps: summary.apps.filter { $0.category == .neutral },
                                       onDropApp: { model.moveApp($0, to: .neutral) })
                    CategoryColumnView(category: .distracting, total: summary.distractingSeconds,
                                       apps: summary.apps.filter { $0.category == .distracting },
                                       onDropApp: { model.moveApp($0, to: .distracting) })
                    CategoryColumnView(category: .excluded,
                                       total: snapshot.excludedApps.reduce(0) { $0 + $1.seconds },
                                       apps: snapshot.excludedApps,
                                       onDropApp: { model.moveApp($0, to: .excluded) })
                }
            }
        }
    }

    // MARK: Helpers

    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
