import Foundation

enum Rating: Int, CaseIterable, Identifiable {
    case again = 1, hard, good, easy
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
}

/// Anki-style SM-2 scheduling, identical to the browser version.
enum Scheduler {
    static let learnSteps: [Double] = [1, 10]   // minutes
    static let relearnMinutes: Double = 10

    static func startOfDay(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }

    static func addDays(_ n: Int, to d: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: startOfDay(d)) ?? d
    }

    static func dayKey(_ d: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    static func answer(_ original: Card, _ r: Rating, now: Date = Date()) -> Card {
        var c = original
        c.reps += 1
        c.lastReviewed = now

        func graduate(_ days: Int) {
            c.state = .review
            c.interval = days
            c.step = 0
            c.due = addDays(days, to: now)
        }

        switch c.state {
        case .new, .learning:
            if c.state == .new { c.state = .learning; c.step = 0 }
            switch r {
            case .again:
                c.step = 0
                c.due = now.addingTimeInterval(learnSteps[0] * 60)
            case .hard:
                let mins = c.step == 0 ? (learnSteps[0] + learnSteps[1]) / 2 : learnSteps[min(c.step, learnSteps.count - 1)]
                c.due = now.addingTimeInterval(mins * 60)
            case .good:
                c.step += 1
                if c.step >= learnSteps.count { graduate(1) } else { c.due = now.addingTimeInterval(learnSteps[c.step] * 60) }
            case .easy:
                graduate(4)
            }
        case .review:
            if r == .again {
                c.lapses += 1
                c.ease = max(1.3, c.ease - 0.2)
                c.state = .relearning
                c.interval = 1
                c.due = now.addingTimeInterval(relearnMinutes * 60)
            } else {
                var next: Double
                switch r {
                case .hard:
                    c.ease = max(1.3, c.ease - 0.15)
                    next = Double(c.interval) * 1.2
                case .good:
                    next = Double(c.interval) * c.ease
                default:
                    c.ease += 0.15
                    next = Double(c.interval) * c.ease * 1.3
                }
                graduate(min(36500, max(c.interval + 1, Int(next.rounded()))))
            }
        case .relearning:
            if r == .again || r == .hard {
                c.due = now.addingTimeInterval(relearnMinutes * 60)
            } else {
                graduate(r == .easy ? c.interval + 1 : c.interval)
            }
        }
        return c
    }

    /// Text under each answer button, e.g. "10m" or "4d".
    static func label(_ c: Card, _ r: Rating, now: Date = Date()) -> String {
        let n = answer(c, r, now: now)
        if n.state == .review { return formatDays(n.interval) }
        return formatMinutes(n.due.timeIntervalSince(now))
    }

    static func formatMinutes(_ seconds: TimeInterval) -> String {
        let m = max(1, Int((seconds / 60).rounded()))
        if m < 60 { return "\(m)m" }
        return "\(Int((Double(m) / 60).rounded()))h"
    }

    static func formatDays(_ d: Int) -> String {
        func trim(_ x: Double) -> String {
            let s = String(format: "%.1f", x)
            return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
        }
        if d < 30 { return "\(d)d" }
        if d < 365 { return trim(Double(d) / 30) + "mo" }
        return trim(Double(d) / 365) + "y"
    }

    static func dueText(_ c: Card, now: Date = Date()) -> String {
        if c.state == .new { return "New" }
        let s = c.due.timeIntervalSince(now)
        if s <= 0 { return "Due now" }
        if c.state != .review { return "Learning · " + formatMinutes(s) }
        let days = Calendar.current.dateComponents([.day], from: startOfDay(now), to: startOfDay(c.due)).day ?? 0
        return days <= 0 ? "Due today" : "Due in " + formatDays(days)
    }
}
