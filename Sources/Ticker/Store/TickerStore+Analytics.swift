import Foundation

/// Derived, read-only aggregations over the stored records. Kept separate from
/// the persistence core so the query surface can grow without bloating the store.
extension TickerStore {

    // MARK: - Apps

    /// All apps ever seen, sorted by lifetime tracked time (most-used first).
    func knownApps() -> [AppTotal] {
        var totals: [String: Int] = [:]
        for rec in recordsByMinute.values {
            for (bundle, secs) in rec.appSeconds { totals[bundle, default: 0] += secs }
        }
        return appNames.keys.map { bundle in
            AppTotal(bundleId: bundle, name: appNames[bundle] ?? bundle,
                     seconds: totals[bundle] ?? 0, category: category(for: bundle))
        }
        .sorted { $0.seconds > $1.seconds }
    }

    func daysWithData() -> [Date] {
        Set(recordsByMinute.keys.map { $0.startOfDay }).sorted(by: >)
    }

    // MARK: - Records in range

    func records(in interval: DateInterval) -> [MinuteRecord] {
        recordsByMinute.values
            .filter { $0.minute >= interval.start && $0.minute < interval.end }
            .sorted { $0.minute < $1.minute }
    }

    func records(on day: Date) -> [MinuteRecord] {
        records(in: Timescale.day.interval(containing: day))
    }

    // MARK: - Summaries

    func summary(in interval: DateInterval) -> DaySummary {
        var summary = DaySummary()
        var perApp: [String: Int] = [:]

        for rec in records(in: interval) {
            summary.keyCount += rec.keyCount
            summary.mouseCount += rec.mouseCount
            for (bundle, secs) in rec.appSeconds {
                let cat = category(for: bundle)
                guard cat.isTracked else { continue }   // Excluded apps don't count at all
                perApp[bundle, default: 0] += secs
                summary.activeSeconds += secs           // active time = tracked time only
                switch cat {
                case .productive: summary.productiveSeconds += secs
                case .neutral: summary.neutralSeconds += secs
                case .distracting: summary.distractingSeconds += secs
                case .excluded: break
                }
            }
        }

        summary.apps = perApp.map { bundle, secs in
            AppTotal(bundleId: bundle, name: appNames[bundle] ?? bundle,
                     seconds: secs, category: category(for: bundle))
        }
        .sorted { $0.seconds > $1.seconds }
        return summary
    }

    func summary(on day: Date) -> DaySummary {
        summary(in: Timescale.day.interval(containing: day))
    }

    /// Per-day category totals across the interval, with empty days filled in.
    func dailyBreakdowns(in interval: DateInterval) -> [DayBreakdown] {
        var map: [Date: (p: Int, n: Int, d: Int)] = [:]
        for rec in records(in: interval) {
            let day = rec.minute.startOfDay
            var totals = map[day] ?? (0, 0, 0)
            for (bundle, secs) in rec.appSeconds {
                switch category(for: bundle) {
                case .productive: totals.p += secs
                case .neutral: totals.n += secs
                case .distracting: totals.d += secs
                case .excluded: break
                }
            }
            map[day] = totals
        }

        var result: [DayBreakdown] = []
        var day = interval.start.startOfDay
        let cal = Calendar.current
        while day < interval.end {
            let t = map[day] ?? (0, 0, 0)
            result.append(DayBreakdown(date: day, productive: t.p, neutral: t.n, distracting: t.d))
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    func dailyProductivity(in interval: DateInterval) -> [ProductivityPoint] {
        dailyBreakdowns(in: interval).map { day in
            let ratio = day.total > 0 ? Double(day.productive) / Double(day.total) : 0
            return ProductivityPoint(date: day.date, productivity: ratio, activeSeconds: day.total)
        }
    }

    /// Interaction totals bucketed across the full day for the activity graph.
    func activityBuckets(on day: Date, bucketMinutes: Int = 15) -> [ActivityBucket] {
        let start = day.startOfDay
        let bucketSeconds = TimeInterval(bucketMinutes * 60)
        let count = (24 * 60) / bucketMinutes

        var sums = Array(repeating: 0, count: count)
        for rec in records(on: day) {
            let index = min(count - 1, max(0, Int(rec.minute.timeIntervalSince(start) / bucketSeconds)))
            sums[index] += rec.interactions
        }
        return (0..<count).map { i in
            ActivityBucket(date: start.addingTimeInterval(Double(i) * bucketSeconds), interactions: sums[i])
        }
    }

    // MARK: - Insights

    /// Active seconds and interactions grouped by hour-of-day across the range.
    func hourlyStats(in interval: DateInterval) -> [HourStat] {
        var active = Array(repeating: 0, count: 24)
        var inter = Array(repeating: 0, count: 24)
        let cal = Calendar.current
        for rec in records(in: interval) {
            let h = cal.component(.hour, from: rec.minute)
            active[h] += rec.activeSeconds
            inter[h] += rec.interactions
        }
        return (0..<24).map { HourStat(hour: $0, activeSeconds: active[$0], interactions: inter[$0]) }
    }

    func contextSwitches(in interval: DateInterval) -> Int {
        records(in: interval).reduce(0) { $0 + $1.switchCount }
    }

    /// Durations (seconds) of continuous "focus" runs: consecutive minutes in
    /// which productive apps dominated, tolerating gaps up to `maxGapMinutes`.
    func focusSessions(in interval: DateInterval, maxGapMinutes: Int = 2) -> [Int] {
        var sessions: [Int] = []
        var current = 0
        var lastMinute: Date?
        let cal = Calendar.current

        for rec in records(in: interval) {
            let productive = rec.appSeconds
                .filter { category(for: $0.key) == .productive }
                .reduce(0) { $0 + $1.value }
            let isFocus = productive >= 30
            let gap = lastMinute.map { cal.dateComponents([.minute], from: $0, to: rec.minute).minute ?? 99 } ?? 0

            if isFocus {
                if current > 0 && gap > maxGapMinutes { sessions.append(current); current = 0 }
                current += productive
                lastMinute = rec.minute
            } else if current > 0 && gap > maxGapMinutes {
                sessions.append(current); current = 0; lastMinute = nil
            }
        }
        if current > 0 { sessions.append(current) }
        return sessions
    }

    /// Time (seconds) toward the focus goal: only a single *continuous* focus
    /// streak counts — the longest sustained run of productive minutes with no
    /// gap longer than 10 minutes. The goal (e.g. 4h) is met only when one such
    /// streak reaches it; fragmented productive blocks spread across the day are
    /// deliberately not summed together. Over a multi-day range we sum each
    /// day's longest streak, so it stays comparable to (daily goal × days).
    func focusedSeconds(in interval: DateInterval) -> Int {
        let cal = Calendar.current
        var total = 0
        var day = interval.start.startOfDay
        while day < interval.end {
            let dayBounds = Timescale.day.interval(containing: day)
            let start = max(dayBounds.start, interval.start)
            let end = min(dayBounds.end, interval.end)
            if end > start {
                let longest = focusSessions(in: DateInterval(start: start, end: end),
                                            maxGapMinutes: 10).max() ?? 0
                total += longest
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return total
    }

    /// Consecutive days (ending today, or yesterday if today isn't met yet)
    /// whose continuous focus time reached the daily goal.
    func focusStreakDays() -> Int {
        let goal = dailyGoalMinutes * 60
        guard goal > 0 else { return 0 }
        let cal = Calendar.current
        let earliest = recordsByMinute.keys.min()?.startOfDay ?? Date().startOfDay

        func metGoal(_ day: Date) -> Bool {
            focusedSeconds(in: Timescale.day.interval(containing: day)) >= goal
        }

        var day = Date().startOfDay
        if !metGoal(day) {
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = prev
        }
        var streak = 0
        while day >= earliest {
            guard metGoal(day) else { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// Trailing 7-day digest (day `ending` inclusive) vs. the previous 7 days.
    func weeklyRecap(ending: Date = Date()) -> WeeklyRecap {
        let cal = Calendar.current
        let todayEnd = cal.date(byAdding: .day, value: 1, to: ending.startOfDay) ?? ending
        let thisWeekStart = cal.date(byAdding: .day, value: -6, to: ending.startOfDay) ?? ending
        let prevWeekStart = cal.date(byAdding: .day, value: -13, to: ending.startOfDay) ?? ending

        let thisWeek = DateInterval(start: thisWeekStart, end: todayEnd)
        let prevWeek = DateInterval(start: prevWeekStart, end: thisWeekStart)

        let summary = self.summary(in: thisWeek)
        var recap = WeeklyRecap()
        recap.productiveSeconds = summary.productiveSeconds
        recap.previousProductiveSeconds = self.summary(in: prevWeek).productiveSeconds
        recap.avgProductivity = summary.productivity

        if let best = dailyBreakdowns(in: thisWeek).max(by: { $0.productive < $1.productive }),
           best.productive > 0 {
            recap.bestDay = best.date
            recap.bestDaySeconds = best.productive
        }
        if let top = summary.apps.first(where: { $0.category == .productive }) ?? summary.apps.first {
            recap.topApp = top.name
            recap.topAppSeconds = top.seconds
        }
        return recap
    }

    // MARK: - Timeline & screenshots

    /// One cell per minute of the day, colored by the dominant app's category.
    func minuteTimeline(on day: Date) -> [MinuteCell] {
        let start = day.startOfDay
        return (0..<1440).map { i in
            let minute = start.addingTimeInterval(Double(i) * 60)
            if let rec = recordsByMinute[minute], rec.activeSeconds > 0,
               let top = rec.appSeconds.max(by: { $0.value < $1.value })?.key {
                return MinuteCell(index: i, minute: minute, category: category(for: top), active: true)
            }
            return MinuteCell(index: i, minute: minute, category: nil, active: false)
        }
    }

    /// The saved thumbnails for a day, tagged with the app that was in focus.
    func screenshots(on day: Date) -> [ScreenShot] {
        let start = day.startOfDay
        let end = start.addingTimeInterval(86_400)
        var shots: [ScreenShot] = []
        forEachScreenshot { url, minute in
            guard minute >= start, minute < end else { return }
            let topBundle = recordsByMinute[minute]?.appSeconds.max(by: { $0.value < $1.value })?.key
            shots.append(ScreenShot(minute: minute, url: url,
                                    appName: topBundle.flatMap { appNames[$0] } ?? "Screen",
                                    category: topBundle.map { category(for: $0) } ?? .neutral))
        }
        return shots.sorted { $0.minute < $1.minute }
    }

    /// Groups the day into 10-minute activity blocks (most recent first), each
    /// with block totals, the screen thumbnail for that window, and a per-minute
    /// keyboard/mouse breakdown. Only blocks with activity are returned.
    func activityBlocks(on day: Date) -> [ActivityBlock] {
        let start = day.startOfDay
        let recs = records(on: day)
        guard !recs.isEmpty else { return [] }
        let shots = screenshots(on: day)

        var grouped: [Date: [MinuteRecord]] = [:]
        for rec in recs {
            let index = Int(rec.minute.timeIntervalSince(start) / 600)
            let blockStart = start.addingTimeInterval(Double(index) * 600)
            grouped[blockStart, default: []].append(rec)
        }

        var blocks: [ActivityBlock] = []
        for (blockStart, blockRecs) in grouped {
            var keys = 0, clicks = 0
            var appSeconds: [String: Int] = [:]
            var contextSeconds: [String: Int] = [:]
            var minutes: [MinuteEntry] = []

            for rec in blockRecs.sorted(by: { $0.minute < $1.minute }) {
                keys += rec.keyCount
                clicks += rec.mouseCount
                // Only tracked apps contribute; excluded apps are ignored entirely.
                for (bundle, secs) in rec.appSeconds where category(for: bundle).isTracked {
                    appSeconds[bundle, default: 0] += secs
                }
                for (ctx, secs) in rec.contextSeconds { contextSeconds[ctx, default: 0] += secs }

                // Skip minutes with no real interaction (idle) or only excluded apps.
                guard rec.keyCount > 0 || rec.mouseCount > 0 else { continue }
                let top = rec.appSeconds
                    .filter { category(for: $0.key).isTracked }
                    .max(by: { $0.value < $1.value })?.key
                guard let top else { continue }
                minutes.append(MinuteEntry(
                    minute: rec.minute, keys: rec.keyCount, clicks: rec.mouseCount,
                    appName: appNames[top] ?? "—", bundleId: top,
                    context: rec.contextSeconds.max(by: { $0.value < $1.value })?.key,
                    category: category(for: top)))
            }

            // Drop zero-activity blocks entirely.
            guard keys + clicks > 0, !minutes.isEmpty else { continue }
            let topApp = appSeconds.max(by: { $0.value < $1.value })?.key
            let blockEnd = blockStart.addingTimeInterval(600)
            let shot = shots.first { $0.minute >= blockStart && $0.minute < blockEnd }?.url

            blocks.append(ActivityBlock(
                start: blockStart, keys: keys, clicks: clicks,
                appName: topApp.flatMap { appNames[$0] } ?? "—", bundleId: topApp,
                context: contextSeconds.max(by: { $0.value < $1.value })?.key,
                category: topApp.map { category(for: $0) } ?? .neutral,
                shotURL: shot, minutes: minutes))
        }
        return blocks.sorted { $0.start > $1.start }
    }
}
