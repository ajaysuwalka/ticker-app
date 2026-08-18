import SwiftUI
import AppKit

/// The menu-bar status item. A lone monochrome glyph is easy to lose among the
/// system icons and reads the same whether we're running or not, so we pin a
/// small status dot beside the ticker glyph to signal state at a glance:
/// green = actively tracking, orange = tracking but idle, hollow gray = paused.
///
/// `MenuBarExtra` renders its SwiftUI label as a *template* image, which strips
/// colour — so we rasterise the label to a non-template `NSImage` ourselves to
/// keep the dot's colour. The glyph follows the system appearance so it stays
/// legible on both light and dark menu bars.
struct MenuBarLabelView: View {
    @ObservedObject var tracker: Tracker
    @Environment(\.colorScheme) private var scheme

    private var dotColor: Color {
        guard tracker.isTracking else { return Color(white: 0.55) }
        return tracker.isActive ? .green : .orange
    }

    var body: some View {
        Image(nsImage: rendered)
            .accessibilityLabel(tracker.isTracking
                ? (tracker.isActive ? "Ticker — tracking" : "Ticker — idle")
                : "Ticker — paused")
    }

    private var rendered: NSImage {
        let glyphColor = scheme == .dark ? Color.white : Color.black
        let content = HStack(spacing: 3) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(glyphColor)
            Group {
                if tracker.isTracking {
                    Circle().fill(dotColor)
                } else {
                    Circle().strokeBorder(dotColor, lineWidth: 1.5)
                }
            }
            .frame(width: 7, height: 7)
        }
        .padding(.vertical, 1)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = false   // preserve the dot colour
        return image
    }
}

/// Menu-bar panel: a live activity waveform, a focus ring with today's numbers,
/// the current app/context, a status pill that toggles tracking, and a bottom
/// action bar. Opening the dashboard shows the full detailed view.
struct MenuBarView: View {
    @EnvironmentObject var store: TickerStore
    @EnvironmentObject var tracker: Tracker
    @EnvironmentObject var breaks: BreakManager
    @Environment(\.openWindow) private var openWindow
    @State private var pillHover = false

    private var summary: DaySummary { store.summary(on: Date().startOfDay) }
    private var todayActivity: [Int] {
        store.activityBuckets(on: Date().startOfDay).map(\.interactions)
    }

    private let brandColor = Color(red: 0.42, green: 0.40, blue: 0.96)
    private let brand = LinearGradient(
        colors: [Color(red: 0.36, green: 0.31, blue: 0.92), Color(red: 0.10, green: 0.71, blue: 0.82)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // The panel sits on a translucent dark material where `.secondary`/`.tertiary`
    // wash out. These appearance-adaptive tints keep supporting text legible.
    private let secondaryText = Color.primary.opacity(0.78)
    private let tertiaryText = Color.primary.opacity(0.6)
    private let fillSubtle = Color.primary.opacity(0.1)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            waveform
            hero
            currentAppChip
            if store.breakRemindersEnabled { breakRow }
            Divider()
            actionBar
        }
        .padding(16)
        .frame(width: 304)
    }

    // MARK: Header — brand + a status pill that toggles tracking

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(brand)
            Text("Ticker")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Spacer()
            statusPill
        }
    }

    private var statusPill: some View {
        let tint = tracker.isTracking ? Color.green : Color.secondary
        return Button { tracker.setTracking(!tracker.isTracking) } label: {
            HStack(spacing: 6) {
                if tracker.isTracking {
                    Circle().fill(tracker.isActive ? Color.green : Color.orange).frame(width: 7, height: 7)
                    Text("Tracking")
                    Image(systemName: "pause.fill").font(.system(size: 8, weight: .bold))   // action hint
                } else {
                    Image(systemName: "play.fill").font(.system(size: 8, weight: .bold))
                    Text("Paused")
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(tint.opacity(pillHover ? 0.24 : 0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(pillHover ? 0.7 : 0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            pillHover = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .help(tracker.isTracking ? "Pause tracking" : "Resume tracking")
    }

    // MARK: Break countdown

    private var breakRow: some View {
        HStack(spacing: 10) {
            breakChip("figure.walk", "Move", breaks.secondsUntilMove)
            breakChip("eye", "Eyes", breaks.secondsUntilScreen)
        }
    }

    private func breakChip(_ symbol: String, _ label: String, _ seconds: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 10)).foregroundStyle(secondaryText)
            Text("\(label) in \(Format.compactDuration(max(60, seconds)))")
                .font(.system(size: 11)).foregroundStyle(secondaryText).monospacedDigit()
        }
        .frame(maxWidth: .infinity)             // each pill takes an equal 50% share
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(fillSubtle, in: Capsule())
    }

    // MARK: Live activity waveform (today)

    private var waveform: some View {
        Sparkline(values: todayActivity.isEmpty ? [0] : todayActivity, color: brandColor)
            .frame(height: 40)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(brandColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Hero — focus ring + today's totals

    private var hero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(brandColor.opacity(0.15), lineWidth: 6)
                Circle().trim(from: 0, to: min(1, summary.productivity))
                    .stroke(brand, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(Format.percent(summary.productivity))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 2) {
                Text(Format.compactDuration(summary.activeSeconds))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("active today").font(.system(size: 11)).foregroundStyle(secondaryText)
                Text("\(Format.compactDuration(summary.productiveSeconds)) productive")
                    .font(.system(size: 11)).foregroundStyle(secondaryText)
            }
            Spacer()
        }
    }

    // MARK: Current app / context

    private var currentAppChip: some View {
        HStack(spacing: 9) {
            if tracker.isTracking, tracker.currentBundleId != nil {
                AppIconView(bundleId: tracker.currentBundleId, size: 20)
            } else {
                Image(systemName: tracker.isTracking ? "hourglass" : "pause.circle")
                    .font(.system(size: 15)).foregroundStyle(secondaryText).frame(width: 20, height: 20)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(mainLabel).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                if tracker.isTracking, let context = tracker.currentContext {
                    Text(context).font(.system(size: 10)).foregroundStyle(tertiaryText).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fillSubtle, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Bottom action bar

    private var actionBar: some View {
        HStack(spacing: 8) {
            actionButton("chart.bar.xaxis", "Dashboard") { openDashboard() }
            SettingsLink { actionLabel("gearshape.fill", "Settings") }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                })
            actionButton("power", "Quit") { quit() }
        }
    }

    private func actionButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { actionLabel(icon, title) }.buttonStyle(.plain)
    }

    private func actionLabel(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(title).font(.system(size: 10, weight: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(fillSubtle, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .foregroundStyle(Color.primary.opacity(0.9))
    }

    // MARK: Derived

    private var mainLabel: String {
        guard tracker.isTracking else { return "Paused" }
        return tracker.isActive ? tracker.currentAppName : "Idle"
    }

    private func openDashboard() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: "dashboard")
    }

    private func quit() {
        store.save()
        NSApplication.shared.terminate(nil)
    }
}
