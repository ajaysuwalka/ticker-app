import SwiftUI
import Charts
import AppKit
import UniformTypeIdentifiers

// MARK: - PDF export

// PDF layout is inherently long (many drawn sections); the body-length rule
// doesn't add value here.
// swiftlint:disable type_body_length
enum PDFReporter {
    /// Builds a light-themed report for the interval and saves it as a PDF.
    @MainActor
    static func export(store: TickerStore, interval: DateInterval, title: String, monthly: Bool) {
        let report = ReportView(
            title: title,
            interval: interval,
            summary: store.summary(in: interval),
            breakdowns: store.dailyBreakdowns(in: interval),
            monthly: monthly)

        guard let data = renderPDF(report, width: 612) else { return }   // 612pt = US Letter width

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName(title: title, interval: interval)
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    /// Renders a SwiftUI view to a single-page PDF via `ImageRenderer`, which
    /// derives the page size from the layout (unlike `NSHostingView.fittingSize`,
    /// which can report zero off-window and produce a blank page).
    @MainActor
    private static func renderPDF(_ view: some View, width: CGFloat) -> Data? {
        let renderer = ImageRenderer(content:
            view.frame(width: width).environment(\.colorScheme, .light))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        renderer.isOpaque = true

        let pdf = NSMutableData()
        renderer.render { size, drawInContext in
            var box = CGRect(origin: .zero, size: size)
            guard size.height > 0,
                  let consumer = CGDataConsumer(data: pdf as CFMutableData),
                  let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            drawInContext(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
        }
        return pdf.isEmpty ? nil : (pdf as Data)
    }

    private static func suggestedName(title: String, interval: DateInterval) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return "Ticker \(title) \(f.string(from: interval.start)).pdf"
    }
}

// MARK: - Report layout

struct ReportView: View {
    let title: String
    let interval: DateInterval
    let summary: DaySummary
    let breakdowns: [DayBreakdown]
    let monthly: Bool

    private let ink = Color(white: 0.11)
    private let sub = Color(white: 0.44)
    private let hair = Color(white: 0.88)
    private let panel = Color(white: 0.965)
    private let brand = LinearGradient(
        colors: [Color(red: 0.36, green: 0.31, blue: 0.92), Color(red: 0.10, green: 0.71, blue: 0.82)],
        startPoint: .leading, endPoint: .trailing)

    private var rangeLabel: String {
        let end = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
        let endStr = end.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(start) – \(endStr)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            header
            statsRow
            splitSection
            chartSection
            topAppsSection
            footer
        }
        .padding(44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(ink)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(brand)
                    Text("PULSE").font(.system(size: 13, weight: .heavy, design: .rounded)).tracking(2)
                }
                Text(title).font(.system(size: 30, weight: .bold, design: .rounded))
                Text(rangeLabel).font(.system(size: 14)).foregroundStyle(sub)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("PRODUCTIVITY").font(.system(size: 10, weight: .semibold)).foregroundStyle(sub)
                Text(Format.percent(summary.productivity))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(AppCategory.productive.color)
            }
        }
    }

    // MARK: Stat tiles

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile("Active time", Format.duration(summary.activeSeconds))
            statTile("Productive", Format.duration(summary.productiveSeconds))
            statTile("Distracting", Format.duration(summary.distractingSeconds))
            statTile("Interactions", "\(summary.keyCount + summary.mouseCount)")
        }
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(panel, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Focus split

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Focus split")
            splitRow(.productive, summary.productiveSeconds)
            splitRow(.neutral, summary.neutralSeconds)
            splitRow(.distracting, summary.distractingSeconds)
        }
    }

    private func splitRow(_ cat: AppCategory, _ seconds: Int) -> some View {
        let frac = summary.activeSeconds > 0 ? Double(seconds) / Double(summary.activeSeconds) : 0
        return HStack(spacing: 12) {
            HStack(spacing: 7) {
                Circle().fill(cat.color).frame(width: 9, height: 9)
                Text(cat.title).font(.system(size: 13, weight: .medium))
            }
            .frame(width: 110, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(cat.color.opacity(0.15))
                    Capsule().fill(cat.color).frame(width: max(4, geo.size.width * frac))
                }
            }
            .frame(height: 8)
            Text(Format.duration(seconds)).font(.system(size: 13)).foregroundStyle(sub)
                .frame(width: 70, alignment: .trailing)
            Text(Format.percent(frac)).font(.system(size: 12, weight: .semibold))
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: Daily chart

    private var dayPoints: [DaySeriesPoint] {
        breakdowns.flatMap { day in
            AppCategory.allCases.map { DaySeriesPoint(date: day.date, category: $0, seconds: day.seconds(for: $0)) }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(monthly ? "Daily focus this month" : "Daily focus this week")
            Chart(dayPoints) { point in
                BarMark(x: .value("Day", point.date, unit: .day),
                        y: .value("Time", point.seconds))
                    .foregroundStyle(by: .value("Category", point.category.title))
                    .cornerRadius(2)
            }
            .chartForegroundStyleScale([
                AppCategory.productive.title: AppCategory.productive.color,
                AppCategory.neutral.title: AppCategory.neutral.color,
                AppCategory.distracting.title: AppCategory.distracting.color
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: monthly ? 5 : 1)) { _ in
                    AxisGridLine().foregroundStyle(hair)
                    AxisValueLabel(format: monthly ? .dateTime.day() : .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(hair)
                    AxisValueLabel { if let s = value.as(Int.self) { Text(Format.compactDuration(s)) } }
                }
            }
            .frame(height: 190)
        }
    }

    // MARK: Top apps

    private var topAppsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Top apps")
            ForEach(Array(summary.apps.prefix(12).enumerated()), id: \.element.id) { index, app in
                HStack(spacing: 10) {
                    Text("\(index + 1)").font(.system(size: 11, weight: .semibold)).foregroundStyle(sub)
                        .frame(width: 18, alignment: .trailing)
                    AppIconView(bundleId: app.bundleId, size: 20, fallbackTint: app.category.color)
                    Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Circle().fill(app.category.color).frame(width: 6, height: 6)
                    Spacer(minLength: 8)
                    Text(Format.duration(app.seconds)).font(.system(size: 13)).foregroundStyle(sub)
                }
                .padding(.vertical, 3)
                if index < min(12, summary.apps.count) - 1 {
                    Rectangle().fill(hair).frame(height: 1)
                }
            }
            if summary.apps.isEmpty {
                Text("No apps tracked in this period.").font(.system(size: 12)).foregroundStyle(sub)
            }
        }
    }

    // MARK: Bits

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold)).tracking(0.6)
            .foregroundStyle(sub)
    }

    private var footer: some View {
        HStack {
            Text("Generated by Ticker · \(Date().formatted(date: .abbreviated, time: .shortened))")
            Spacer()
            Text("All data stays on your Mac")
        }
        .font(.system(size: 10)).foregroundStyle(sub)
        .padding(.top, 6)
        .overlay(alignment: .top) { Rectangle().fill(hair).frame(height: 1) }
    }
}
