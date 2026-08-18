import SwiftUI
import Charts
import AppKit

// MARK: - Charts

/// Day view: interactions across the hours of the day.
struct ActivityChart: View {
    let buckets: [ActivityBucket]

    var body: some View {
        Chart(buckets) { bucket in
            AreaMark(
                x: .value("Time", bucket.date),
                y: .value("Interactions", bucket.interactions)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [Color.accentColor.opacity(0.45), Color.accentColor.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Time", bucket.date),
                y: .value("Interactions", bucket.interactions)
            )
            .foregroundStyle(Color.accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.04))
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.05))
                AxisValueLabel()
            }
        }
    }
}

/// Week / month view: stacked category time per day.
struct RangeBarChart: View {
    let breakdowns: [DayBreakdown]
    let scope: Timescale

    private var points: [DaySeriesPoint] {
        breakdowns.flatMap { day in
            AppCategory.tracked.map { cat in
                DaySeriesPoint(date: day.date, category: cat, seconds: day.seconds(for: cat))
            }
        }
    }

    private var xLabelFormat: Date.FormatStyle {
        scope == .week ? .dateTime.weekday(.abbreviated) : .dateTime.day()
    }

    private var xStride: Int { scope == .week ? 1 : 5 }

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Time", point.seconds)
            )
            .foregroundStyle(by: .value("Category", point.category.title))
            .cornerRadius(3)
        }
        .chartForegroundStyleScale([
            AppCategory.productive.title: AppCategory.productive.color,
            AppCategory.neutral.title: AppCategory.neutral.color,
            AppCategory.distracting.title: AppCategory.distracting.color
        ])
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xStride)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.04))
                AxisValueLabel(format: xLabelFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.05))
                AxisValueLabel {
                    if let secs = value.as(Int.self) {
                        Text(Format.compactDuration(secs))
                    }
                }
            }
        }
    }
}

/// Everything the dashboard renders, computed once per refresh so scrolling and
/// per-second tracking never trigger the heavy queries.
struct DashboardSnapshot {
    var scope: Timescale = .day
    var summary = DaySummary()
    var dayBuckets: [ActivityBucket] = []
    var breakdowns: [DayBreakdown] = []
    var trend: [ProductivityPoint] = []
    var hourStats: [HourStat] = []
    var sessions: [Int] = []
    var streak = 0
    var contextSwitches = 0
    var goalDays = 1
    var dailyGoalMinutes = 240
    var focusedSeconds = 0          // continuous-focus time toward the goal
    var weeklyActiveSeconds = 0     // total tracked time in the anchor's week
    var weeklyGoalHours = 40        // target total hours for the week
    var recap = WeeklyRecap()
    var minuteCells: [MinuteCell] = []
    var shots: [ScreenShot] = []
    var blocks: [ActivityBlock] = []
    var excludedApps: [AppTotal] = []
    var captureEnabled = false
}

/// The only piece that updates live (once per second). Kept tiny and isolated so
/// the rest of the dashboard doesn't re-render with it.
struct LiveStatusView: View {
    @EnvironmentObject var tracker: Tracker

    private var color: Color {
        guard tracker.isTracking else { return .secondary }
        return tracker.isActive ? .green : .secondary
    }
    private var status: String {
        guard tracker.isTracking else { return "Paused" }
        return tracker.isActive ? "Active" : "Idle"
    }

    var body: some View {
        // Just the tracking status. The active app/window is intentionally not
        // shown in the main app's sidebar.
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(status).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
        }
    }
}

/// Always-visible "next breaks" panel for the sidebar: both wellness timers
/// (move + screen) with live countdowns, the sooner one highlighted. Ticks every
/// second via its own TimelineView so it never forces a full dashboard refresh.
struct SidebarBreaksView: View {
    @EnvironmentObject var breaks: BreakManager
    @EnvironmentObject var store: TickerStore

    var body: some View {
        if store.breakRemindersEnabled {
            TimelineView(.periodic(from: .now, by: 1)) { _ in panel }
        }
    }

    private var panel: some View {
        let move = breaks.secondsUntilMove
        let screen = breaks.secondsUntilScreen
        let soonest: BreakKind = move <= screen ? .move : .screen
        return VStack(alignment: .leading, spacing: 7) {
            Text("NEXT BREAKS")
                .font(.system(size: 9, weight: .bold)).tracking(0.6)
                .foregroundStyle(.tertiary)
            row(.move, seconds: move, highlighted: soonest == .move)
            row(.screen, seconds: screen, highlighted: soonest == .screen)
        }
    }

    private func row(_ kind: BreakKind, seconds: Int, highlighted: Bool) -> some View {
        let tint = kind == .move ? Color(red: 0.24, green: 0.80, blue: 0.50)
                                 : Color(red: 0.42, green: 0.60, blue: 1.0)
        return HStack(spacing: 8) {
            Image(systemName: kind.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint).frame(width: 16)
            Text(kind.shortLabel)
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(seconds <= 0 ? "now" : Self.format(seconds))
                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(tint.opacity(highlighted ? 0.14 : 0), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    static func format(_ s: Int) -> String {
        s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
                  : String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Start/Pause tracking button. Observes the tracker in isolation so toggling
/// live status doesn't re-render the whole dashboard.
struct TrackingToggle: View {
    @EnvironmentObject var tracker: Tracker

    var body: some View {
        Button { tracker.setTracking(!tracker.isTracking) } label: {
            Label(tracker.isTracking ? "Pause" : "Resume",
                  systemImage: tracker.isTracking ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.bordered)
        .tint(tracker.isTracking ? .orange : .green)
        .help(tracker.isTracking ? "Pause tracking" : "Resume tracking")
    }
}

/// Active minutes per hour-of-day, with the peak hour highlighted.
struct HourBarChart: View {
    let stats: [HourStat]
    let peakHour: Int?

    var body: some View {
        Chart(stats) { s in
            BarMark(
                x: .value("Hour", s.hour),
                y: .value("Active minutes", s.activeSeconds / 60)
            )
            .foregroundStyle(s.hour == peakHour
                             ? AppCategory.productive.color
                             : Color.accentColor.opacity(0.55))
            .cornerRadius(3)
        }
        .chartXScale(domain: -0.5...23.5)
        .chartXAxis {
            AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21]) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.04))
                AxisValueLabel {
                    if let h = value.as(Int.self) { Text(Format.hourLabel(h)) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.05))
                AxisValueLabel {
                    if let m = value.as(Int.self) { Text("\(m)m") }
                }
            }
        }
    }
}

/// Dense per-minute strip (1440 cells) colored by the dominant app's category.
struct MinuteTimelineStrip: View {
    let cells: [MinuteCell]

    var body: some View {
        Canvas { ctx, size in
            let cellW = size.width / 1440.0
            for cell in cells {
                let x = Double(cell.index) * cellW
                let rect = CGRect(x: x, y: 0, width: max(cellW, 0.75), height: size.height)
                ctx.fill(Path(rect), with: .color(color(for: cell)))
            }
        }
        .drawingGroup()
    }

    private func color(for cell: MinuteCell) -> Color {
        guard cell.active, let cat = cell.category else { return Color.secondary.opacity(0.12) }
        return cat.color
    }
}

/// One category column in the "where your time went" breakdown. Apps are
/// draggable; dropping an app onto another column recategorizes it.
struct CategoryColumnView: View {
    let category: AppCategory
    let total: Int
    let apps: [AppTotal]
    var onDropApp: (String) -> Void
    @State private var targeted = false

    private let visibleLimit = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Compact one-line header: title + total.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(category.color).frame(width: 7, height: 7)
                Text(category.title).font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer(minLength: 4)
                Text(Format.duration(total))
                    .font(.system(size: 12, weight: .medium)).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 2).fill(category.color).frame(height: 3)

            if apps.isEmpty {
                Text(targeted ? "Drop to move here" : "—")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 34)
            } else {
                VStack(spacing: 1) {
                    ForEach(apps.prefix(visibleLimit)) { CompactAppRow(app: $0) }
                }
                if apps.count > visibleLimit {
                    Text("+\(apps.count - visibleLimit) more")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                        .padding(.leading, 6).padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(targeted ? category.color.opacity(0.14) : Color.secondary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(targeted ? category.color : Color.clear, lineWidth: 1.5)
        )
        .dropDestination(for: String.self) { items, _ in
            items.forEach { onDropApp($0) }
            return !items.isEmpty
        } isTargeted: { targeted = $0 }
    }
}

/// Dense, draggable one-line app row for the category columns.
struct CompactAppRow: View {
    let app: AppTotal
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 8) {
            AppIconView(bundleId: app.bundleId, size: 18, fallbackTint: app.category.color)
            Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
            Spacer(minLength: 6)
            Text(Format.duration(app.seconds))
                .font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9))
                .foregroundStyle(hovered ? .secondary : Color.secondary.opacity(0.35))
        }
        .padding(.vertical, 5).padding(.horizontal, 7)
        .background(hovered ? Color.secondary.opacity(0.10) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { h in
            hovered = h
            if h { NSCursor.openHand.push() } else { NSCursor.pop() }
        }
        .draggable(app.bundleId) {
            HStack(spacing: 6) {
                AppIconView(bundleId: app.bundleId, size: 18, fallbackTint: app.category.color)
                Text(app.name).font(.system(size: 12, weight: .medium))
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// A 10-minute activity block as a tile: screenshot preview + compact summary.
/// Tap for a popover with the per-minute breakdown; the popover's screenshot
/// opens the full-screen viewer.
struct ActivityBlockTile: View {
    let block: ActivityBlock
    var captureEnabled: Bool = true
    var onOpenShot: (URL) -> Void = { _ in }
    var onDeleteShots: () -> Void = {}
    @State private var showDetail = false
    @State private var confirmDelete = false
    @State private var hovered = false

    private var rangeLabel: String {
        let f = Date.FormatStyle.dateTime.hour().minute()
        return "\(block.start.formatted(f)) – \(block.end.formatted(f))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
            footer
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.06)))
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .onHover { hovered = $0 }
        .popover(isPresented: $showDetail, arrowEdge: .bottom) { detailPopover }
        .confirmationDialog("Delete this block's screenshot? This can't be undone.",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Screenshot", role: .destructive) { onDeleteShots(); showDetail = false }
            Button("Cancel", role: .cancel) {}
        }
    }

    // Screenshot preview (or a graceful placeholder) with a time chip.
    private var preview: some View {
        ZStack {
            if let url = block.shotURL {
                ThumbView(url: url)
                    .frame(maxWidth: .infinity).frame(height: 124).clipped()
            } else {
                Rectangle().fill(Color.secondary.opacity(0.08))
                    .frame(maxWidth: .infinity).frame(height: 124)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: captureEnabled ? "photo" : "eye.slash")
                                .font(.system(size: 18)).foregroundStyle(.tertiary)
                            Text(captureEnabled ? "Not available" : "Screenshots off")
                                .font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                    )
            }
        }
        .overlay(alignment: .topLeading) {
            Text(rangeLabel)
                .font(.system(size: 10, weight: .semibold)).monospacedDigit()
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(.black.opacity(0.45), in: Capsule())
                .foregroundStyle(.white)
                .padding(6)
        }
        .overlay(alignment: .topTrailing) {
            if hovered && block.shotURL != nil {
                Button { confirmDelete = true } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.55), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("Delete screenshot")
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AppIconView(bundleId: block.bundleId, size: 16, fallbackTint: block.category.color)
                Text(block.appName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Circle().fill(block.category.color).frame(width: 6, height: 6)
                Spacer(minLength: 0)
            }
            if let context = block.context {
                Text(context)
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(spacing: 10) {
                stat("keyboard", block.keys)
                stat("cursorarrow.click", block.clicks)
                Spacer(minLength: 0)
                Sparkline(values: block.minutes.map { $0.keys + $0.clicks }, color: block.category.color)
                    .frame(width: 52, height: 14)
            }
        }
        .padding(10)
    }

    // Per-minute breakdown popover.
    private var detailPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(block.category.color).frame(width: 8, height: 8)
                Text(rangeLabel).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                Spacer()
                stat("keyboard", block.keys)
                stat("cursorarrow.click", block.clicks)
                if block.shotURL != nil {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Image(systemName: "trash").font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Delete this block's screenshot")
                }
            }
            if let url = block.shotURL {
                ThumbView(url: url, fill: false)
                    .frame(maxWidth: .infinity).frame(height: 150)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { showDetail = false; onOpenShot(url) }
                    .help("Open full screenshot")
            }
            Divider()
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(block.minutes) { m in
                        HStack(spacing: 10) {
                            Text(m.minute, format: .dateTime.hour().minute())
                                .font(.system(size: 11, weight: .medium)).monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 58, alignment: .leading)
                            miniStat("keyboard", m.keys)
                            miniStat("cursorarrow.click", m.clicks)
                            AppIconView(bundleId: m.bundleId, size: 13, fallbackTint: m.category.color)
                            Text(m.context ?? m.appName)
                                .font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(14)
        .frame(width: 320)
    }

    private func stat(_ symbol: String, _ n: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(.secondary)
            Text("\(n)").font(.system(size: 12, weight: .semibold)).monospacedDigit()
        }
    }

    private func miniStat(_ symbol: String, _ n: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9)).foregroundStyle(.tertiary)
            Text("\(n)").font(.system(size: 11)).monospacedDigit()
                .frame(width: 30, alignment: .leading)
        }
    }
}

/// Tiny inline bar chart of per-minute interaction counts.
