import SwiftUI

/// A friendly, self-explanatory break reminder: which break, why, how long, the
/// guidance, and how to change it — with Done / Snooze actions. Rendered on a
/// solid high-contrast dark card so it's readable over any background.
struct BreakOverlayView: View {
    let kind: BreakKind
    var intervalMinutes: Int          // the configured interval that triggered it
    var breakSeconds: Int             // length of the on-screen break countdown
    var onComplete: () -> Void        // fired when the countdown reaches zero
    var onSnooze: () -> Void

    @State private var remaining: Int = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var tint: Color {
        kind == .move ? Color(red: 0.24, green: 0.80, blue: 0.50)
                      : Color(red: 0.42, green: 0.60, blue: 1.0)
    }
    private let cardBG = Color(red: 0.12, green: 0.13, blue: 0.16)
    private let ink = Color.white
    private let sub = Color.white.opacity(0.76)
    private let faint = Color.white.opacity(0.52)

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.5)).ignoresSafeArea()
            card
        }
        .environment(\.colorScheme, .dark)
        .transition(.opacity)
        .onAppear { remaining = breakSeconds }   // countdown starts as the popup appears
        .onReceive(ticker) { _ in
            guard remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 { onComplete() }   // auto-finishes the break
        }
    }

    private var clock: String {
        let s = max(0, remaining)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
    private var progress: Double {
        breakSeconds > 0 ? Double(breakSeconds - remaining) / Double(breakSeconds) : 0
    }

    private var card: some View {
        VStack(spacing: 0) {
            banner
            VStack(alignment: .leading, spacing: 16) {
                infoRow(icon: "clock.badge.checkmark",
                        title: tr("Why now"),
                        detail: String(format: tr("%@ It's been about %d minutes."),
                                       kind.reason, intervalMinutes))
                infoRow(icon: "timer",
                        title: tr("How long"),
                        detail: String(format: tr("Take %@. The timer below counts down and finishes the "
                                                  + "break on its own — or step away and it's done."),
                                       kind.recommendedDuration))

                VStack(alignment: .leading, spacing: 9) {
                    Text("SUGGESTIONS")
                        .font(.system(size: 10, weight: .bold)).tracking(0.6)
                        .foregroundStyle(faint)
                    ForEach(kind.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13)).foregroundStyle(tint)
                            Text(tip).font(.system(size: 12.5)).foregroundStyle(sub)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.08)))

                Text("Repeats every \(intervalMinutes) min · change in Settings → Wellness")
                    .font(.system(size: 10.5)).foregroundStyle(faint)

                countdown

                HStack {
                    Spacer(minLength: 0)
                    Button { onSnooze() } label: {
                        Label("Snooze 5 min", systemImage: "zzz")
                    }
                    .buttonStyle(.bordered).controlSize(.large).tint(.white)
                    Spacer(minLength: 0)
                }
            }
            .padding(20)
        }
        .frame(width: 440)
        .background(cardBG, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.14)))
        .shadow(color: .black.opacity(0.45), radius: 40, y: 16)
        .foregroundStyle(ink)
    }

    // The break timer: a ring + big mm:ss that starts the moment this appears
    // and finishes the break on its own at zero.
    private var countdown: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 6)
                Circle().trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                Image(systemName: kind.symbol).font(.system(size: 18)).foregroundStyle(tint)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(clock)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundStyle(ink)
                    .contentTransition(.numericText())
                Text("Break ends automatically")
                    .font(.system(size: 12)).foregroundStyle(sub)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.25)))
    }

    // Colored banner with the icon, title, and headline.
    private var banner: some View {
        HStack(spacing: 14) {
            Image(systemName: kind.symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                Text(kind.headline)
                    .font(.system(size: 13)).foregroundStyle(sub)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.20))
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15)).foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(ink)
                Text(detail).font(.system(size: 12.5)).foregroundStyle(sub)
            }
            Spacer(minLength: 0)
        }
    }
}
