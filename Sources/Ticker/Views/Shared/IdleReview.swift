import SwiftUI
import AppKit
import Combine

/// Two-step review card shown when the user returns after ≥10 minutes away:
/// step 1 asks whether it was a meeting (Yes → productive), and choosing "No"
/// reveals step 2, offering to delete the idle time. Reuses the floating,
/// above-everything `FloatingPanel` so it's visible over any app.
struct IdleReviewView: View {
    let period: IdlePeriod
    var onMeeting: () -> Void
    var onDelete: () -> Void
    var onKeep: () -> Void

    @State private var confirmingDelete = false

    private let tint = Color(red: 0.42, green: 0.60, blue: 1.0)
    private let cardBG = Color(red: 0.12, green: 0.13, blue: 0.16)

    private var range: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "\(f.string(from: period.start)) – \(f.string(from: period.end))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: confirmingDelete ? "trash.circle.fill" : "moon.zzz.fill")
                .font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                if confirmingDelete {
                    Text("Delete this idle time?")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("Removes \(period.minutes) min (\(range)) from your tracked data.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.72))
                    HStack(spacing: 8) {
                        Button("Delete") { onDelete() }
                            .buttonStyle(.borderedProminent).controlSize(.small).tint(.red)
                        Button("Keep as idle") { onKeep() }
                            .buttonStyle(.bordered).controlSize(.small).tint(.white)
                    }
                    .padding(.top, 3)
                } else {
                    Text("You were away for \(period.minutes) min")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("\(range) · Was this a meeting or focused work away from the keyboard?")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.72))
                    HStack(spacing: 8) {
                        Button("Yes, it was a meeting") { onMeeting() }
                            .buttonStyle(.borderedProminent).controlSize(.small).tint(tint)
                        Button("No") { confirmingDelete = true }
                            .buttonStyle(.bordered).controlSize(.small).tint(.white)
                    }
                    .padding(.top, 3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 420, alignment: .leading)
        .background(cardBG, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.14)))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
        .environment(\.colorScheme, .dark)
    }
}

/// Floats the idle-review card near the top of the screen, above other apps,
/// whenever the tracker publishes a pending away period.
@MainActor
final class IdleReviewPresenter: ObservableObject {
    private let tracker: Tracker
    private var panel: FloatingPanel?
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    init(tracker: Tracker) { self.tracker = tracker }

    func start() {
        guard !started else { return }
        started = true
        tracker.$pendingIdleReview
            .receive(on: RunLoop.main)
            .sink { [weak self] period in
                if let period { self?.show(period) } else { self?.hide() }
            }
            .store(in: &cancellables)
    }

    private func show(_ period: IdlePeriod) {
        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: 420, height: 116)
        let view = IdleReviewView(
            period: period,
            onMeeting: { [weak self] in self?.tracker.confirmIdleWasMeeting() },
            onDelete: { [weak self] in self?.tracker.discardIdlePeriod() },
            onKeep: { [weak self] in self?.tracker.keepIdlePeriod() })

        let panel = self.panel ?? makePanel()
        panel.contentView = NSHostingView(rootView: view)
        let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2,
                             y: screen.visibleFrame.maxY - size.height - 12)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func makePanel() -> FloatingPanel {
        let p = FloatingPanel(contentRect: .zero,
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        p.level = .statusBar
        p.appearance = NSAppearance(named: .darkAqua)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return p
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
