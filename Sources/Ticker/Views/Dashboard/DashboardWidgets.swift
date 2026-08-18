import SwiftUI
import Charts
import AppKit

struct Sparkline: View {
    let values: [Int]
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            guard !values.isEmpty else { return }
            let maxV = CGFloat(max(values.max() ?? 1, 1))
            let gap: CGFloat = 2
            let n = CGFloat(values.count)
            let barW = max(1, (size.width - gap * (n - 1)) / n)
            for (i, v) in values.enumerated() {
                let h = max(1.5, size.height * CGFloat(v) / maxV)
                let x = CGFloat(i) * (barW + gap)
                let rect = CGRect(x: x, y: size.height - h, width: barW, height: h)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color.opacity(0.85)))
            }
        }
    }
}

/// A single minute's screenshot thumbnail with its time and focused app.
struct ScreenshotCard: View {
    let shot: ScreenShot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ThumbView(url: shot.url)
                .frame(maxWidth: .infinity)
                .frame(height: 118)
                .clipped()
            HStack(spacing: 6) {
                Circle().fill(shot.category.color).frame(width: 7, height: 7)
                Text(shot.minute, format: .dateTime.hour().minute())
                    .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                Text(shot.appName)
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(8)
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }
}

/// Loads a screenshot thumbnail off the main thread; lazy in a grid.
struct ThumbView: View {
    let url: URL
    var fill: Bool = true
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: fill ? .fill : .fit)
            } else {
                Rectangle().fill(Color.secondary.opacity(0.10))
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .task(id: url) {
            let target = url
            image = await Task.detached { NSImage(contentsOf: target) }.value
        }
    }
}

/// Full-size screenshot viewer with prev/next navigation (buttons + arrow keys).
struct ScreenshotViewer: View {
    @Binding var index: Int
    var onDelete: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ScreenShot]
    @State private var confirmDelete = false

    init(shots: [ScreenShot], index: Binding<Int>, onDelete: @escaping (URL) -> Void = { _ in }) {
        self._index = index
        self.onDelete = onDelete
        self._items = State(initialValue: shots)
    }

    private var current: ScreenShot? {
        items.indices.contains(index) ? items[index] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            imageArea
            Divider()
            footer
        }
        .frame(minWidth: 780, minHeight: 580)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let s = current {
                Circle().fill(s.category.color).frame(width: 9, height: 9)
                Text(s.minute, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                Text(s.appName).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text("\(min(index + 1, items.count)) of \(items.count)")
                .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
            Button(role: .destructive) { confirmDelete = true } label: {
                Image(systemName: "trash")
            }
            .help("Delete this screenshot")
            .confirmationDialog("Delete this screenshot? This can't be undone.",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Screenshot", role: .destructive) { deleteCurrent() }
                Button("Cancel", role: .cancel) {}
            }
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .keyboardShortcut(.cancelAction)
                .help("Close")
        }
        .padding(14)
    }

    private var imageArea: some View {
        ZStack {
            Rectangle().fill(Color.black.opacity(0.06))
            if let s = current {
                ThumbView(url: s.url, fill: false)
                    .id(s.url)
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button { step(-1) } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(index <= 0)

            Spacer()

            Button { step(1) } label: {
                Label("Next", systemImage: "chevron.right").labelStyle(.titleAndIcon)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(index >= items.count - 1)
        }
        .controlSize(.large)
        .padding(14)
    }

    private func step(_ delta: Int) {
        let next = index + delta
        if items.indices.contains(next) { index = next }
    }

    private func deleteCurrent() {
        guard items.indices.contains(index) else { return }
        onDelete(items[index].url)
        items.remove(at: index)
        if items.isEmpty { dismiss(); return }
        if index >= items.count { index = items.count - 1 }
    }
}

/// Circular progress ring for the daily focus goal.
struct GoalRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppCategory.productive.color.opacity(0.15), lineWidth: 11)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(AppCategory.productive.color,
                        style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
            Text(Format.percent(min(1, progress)))
                .font(.system(size: 17, weight: .bold, design: .rounded))
        }
    }
}

/// Productivity % over time, as a filled line.
struct ProductivityTrendChart: View {
    let points: [ProductivityPoint]

    private var strideCount: Int { max(1, points.count / 7) }
    private var average: Double {
        let active = points.filter { $0.activeSeconds > 0 }
        guard !active.isEmpty else { return 0 }
        return active.map(\.productivity).reduce(0, +) / Double(active.count)
    }

    var body: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(
                    x: .value("Day", p.date, unit: .day),
                    y: .value("Productivity", p.productivity)
                )
                .foregroundStyle(
                    .linearGradient(colors: [AppCategory.productive.color.opacity(0.30), .clear],
                                    startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Day", p.date, unit: .day),
                    y: .value("Productivity", p.productivity)
                )
                .foregroundStyle(AppCategory.productive.color)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", p.date, unit: .day),
                    y: .value("Productivity", p.productivity)
                )
                .foregroundStyle(AppCategory.productive.color)
                .symbolSize(26)
            }

            RuleMark(y: .value("Average", average))
                .foregroundStyle(.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text("avg \(Format.percent(average))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.05))
                AxisValueLabel {
                    if let d = value.as(Double.self) { Text("\(Int(d * 100))%") }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: strideCount)) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.04))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }
}

struct CategoryDonut: View {
    let summary: DaySummary

    private var slices: [(AppCategory, Int)] {
        [(.productive, summary.productiveSeconds),
         (.neutral, summary.neutralSeconds),
         (.distracting, summary.distractingSeconds)]
            .filter { $0.1 > 0 }
    }

    var body: some View {
        Chart(slices, id: \.0) { slice in
            SectorMark(
                angle: .value("Seconds", slice.1),
                innerRadius: .ratio(0.62),
                angularInset: 2
            )
            .foregroundStyle(slice.0.color)
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 0) {
                Text(Format.percent(summary.productivity))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("focused")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A custom month calendar: brand-gradient selected day, a "today" ring, dots on
/// days with tracked data, dimmed future days, and an optional week highlight.
struct CalendarPicker: View {
    @Binding var selection: Date
    var daysWithData: Set<Date> = []
    var weekHighlight: DateInterval? = nil
    var footnote: String? = nil
    var onPick: () -> Void = {}

    @State private var month: Date = Date()

    private let cal = Calendar.mondayFirst   // month grid starts weeks on Monday
    private let brand = LinearGradient(
        colors: [Color(red: 0.36, green: 0.31, blue: 0.92), Color(red: 0.10, green: 0.71, blue: 0.82)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    private var today: Date { Date().startOfDay }

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayRow
            grid
            if let footnote {
                Divider().padding(.top, 2)
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .onAppear { month = startOfMonth(selection) }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            navButton("chevron.left") { shiftMonth(-1) }
                .disabled(false)
            Spacer()
            Text(month, format: .dateTime.month(.wide).year())
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            navButton("chevron.right") { shiftMonth(1) }
                .disabled(!canGoNext)
                .opacity(canGoNext ? 1 : 0.35)
        }
    }

    private func navButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 28, height: 28)
                .background(.background.secondary, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols.indices, id: \.self) { i in
                Text(orderedWeekdaySymbols[i])
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear.frame(height: 36)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let day = date.startOfDay
        let isSelected = cal.isDate(day, inSameDayAs: selection.startOfDay)
        let isToday = cal.isDate(day, inSameDayAs: today)
        let isFuture = day > today
        let inWeek = (weekHighlight?.contains(day) ?? false) && !isSelected
        let hasData = daysWithData.contains(day)

        return Button {
            guard !isFuture else { return }
            selection = day
            onPick()
        } label: {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(dayColor(isSelected: isSelected, isFuture: isFuture))
                Circle()
                    .fill(isSelected ? Color.white : AppCategory.productive.color)
                    .frame(width: 4, height: 4)
                    .opacity(hasData ? (isFuture ? 0.3 : 1) : 0)
            }
            .frame(width: 36, height: 36)
            .background(cellBackground(isSelected: isSelected, isToday: isToday, inWeek: inWeek))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    @ViewBuilder
    private func cellBackground(isSelected: Bool, isToday: Bool, inWeek: Bool) -> some View {
        ZStack {
            if inWeek {
                Circle().fill(Color.accentColor.opacity(0.12))
            }
            if isSelected {
                Circle().fill(brand)
                    .shadow(color: Color(red: 0.24, green: 0.28, blue: 0.85).opacity(0.35), radius: 5, y: 2)
            } else if isToday {
                Circle().strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1.5)
            }
        }
    }

    private func dayColor(isSelected: Bool, isFuture: Bool) -> Color {
        if isSelected { return .white }
        if isFuture { return Color.secondary.opacity(0.35) }
        return .primary
    }

    // MARK: Calendar math

    private var orderedWeekdaySymbols: [String] {
        let syms = cal.veryShortWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(syms[start...] + syms[..<start])
    }

    private var days: [Date?] {
        let first = startOfMonth(month)
        let range = cal.range(of: .day, in: .month, for: first) ?? 1..<29
        let firstWeekday = cal.component(.weekday, from: first)
        let lead = (firstWeekday - cal.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: lead)
        for day in range {
            result.append(cal.date(byAdding: .day, value: day - 1, to: first))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private func startOfMonth(_ date: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private var canGoNext: Bool {
        startOfMonth(month) < startOfMonth(today)
    }

    private func shiftMonth(_ delta: Int) {
        guard let moved = cal.date(byAdding: .month, value: delta, to: month) else { return }
        if delta > 0 && startOfMonth(moved) > startOfMonth(today) { return }
        month = startOfMonth(moved)
    }
}

/// Uses the standard window material as the scroll background.
struct WindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underPageBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
