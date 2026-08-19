import SwiftUI
import AppKit

/// A rounded, subtly bordered surface used for every dashboard panel.
struct Card<Content: View>: View {
    var padding: CGFloat = 18
    var fill: Bool = false          // stretch to fill the height offered (for equal-height rows)
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: fill ? .infinity : nil,
                   alignment: fill ? .topLeading : .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.background.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.06))
            )
    }
}

struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 30, height: 30)
                        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Spacer()
                }
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct SectionTitle: View {
    let text: LocalizedStringKey
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 7) {
            if let symbol {
                Image(systemName: symbol).foregroundStyle(.secondary)
            }
            Text(text)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.bottom, 2)
    }
}

/// Resolves and caches real app icons by bundle id (via LaunchServices).
enum AppIconCache {
    @MainActor private static var cache: [String: NSImage] = [:]
    @MainActor private static var missing: Set<String> = []

    @MainActor
    static func icon(for bundleId: String?) -> NSImage? {
        guard let bundleId else { return nil }
        if let cached = cache[bundleId] { return cached }
        if missing.contains(bundleId) { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            missing.insert(bundleId)
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleId] = image
        return image
    }
}

/// Shows an app's icon, or a neutral placeholder tile if it can't be resolved.
struct AppIconView: View {
    let bundleId: String?
    var size: CGFloat = 18
    var fallbackTint: Color = .secondary

    var body: some View {
        if let icon = AppIconCache.icon(for: bundleId) {
            Image(nsImage: icon).resizable().interpolation(.high)
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(fallbackTint.opacity(0.22))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "app.dashed")
                        .font(.system(size: size * 0.55))
                        .foregroundStyle(fallbackTint)
                )
        }
    }
}

/// A thin capsule progress bar (used for per-app share and category legend).
struct MiniBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15))
                Capsule().fill(color)
                    .frame(width: max(3, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 6)
    }
}
