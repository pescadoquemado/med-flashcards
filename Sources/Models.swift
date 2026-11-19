import Foundation

enum CardState: Int, Codable {
    case new = 0, learning = 1, review = 2, relearning = 3

    var label: String {
        switch self {
        case .new: return "New"
        case .learning: return "Learning"
        case .review: return "Review"
        case .relearning: return "Relearning"
        }
    }
}

let epoch = Date(timeIntervalSince1970: 0)

struct Card: Codable, Identifiable, Equatable {
    var id: String
    var front: String
    var back: String
    var tag: String = ""
    var state: CardState = .new
    var step: Int = 0
    var due: Date = epoch
    var interval: Int = 0          // days
    var ease: Double = 2.5
    var reps: Int = 0
    var lapses: Int = 0
    var lastReviewed: Date? = nil  // drives progress merging
    var modified: Date = epoch     // drives text merging
    var userEdited: Bool = false   // bundled updates never overwrite your edits

    enum CodingKeys: String, CodingKey {
        case id, front, back, tag, state, step, due, interval, ease, reps, lapses, lastReviewed, modified, userEdited
    }

    mutating func applyProgress(from o: Card) {
        state = o.state; step = o.step; due = o.due; interval = o.interval
        ease = o.ease; reps = o.reps; lapses = o.lapses; lastReviewed = o.lastReviewed
    }

    mutating func resetProgress() {
        state = .new; step = 0; due = epoch; interval = 0; ease = 2.5; reps = 0; lapses = 0
        lastReviewed = Date()
    }
}

extension Card {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        front = try c.decode(String.self, forKey: .front)
        back = try c.decode(String.self, forKey: .back)
        tag = try c.decodeIfPresent(String.self, forKey: .tag) ?? ""
        state = try c.decodeIfPresent(CardState.self, forKey: .state) ?? .new
        step = try c.decodeIfPresent(Int.self, forKey: .step) ?? 0
        due = try c.decodeIfPresent(Date.self, forKey: .due) ?? epoch
        interval = try c.decodeIfPresent(Int.self, forKey: .interval) ?? 0
        ease = try c.decodeIfPresent(Double.self, forKey: .ease) ?? 2.5
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        lapses = try c.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
        lastReviewed = try c.decodeIfPresent(Date.self, forKey: .lastReviewed)
        modified = try c.decodeIfPresent(Date.self, forKey: .modified) ?? epoch
        userEdited = try c.decodeIfPresent(Bool.self, forKey: .userEdited) ?? false
    }
}

struct Deck: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var created: Date = Date()
    var cards: [Card] = []
    var newDay: String = ""
    var newDone: Int = 0
    var bundled: Bool = false

    enum CodingKeys: String, CodingKey { case id, name, created, cards, newDay, newDone, bundled }
}

extension Deck {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? epoch
        cards = try c.decodeIfPresent([Card].self, forKey: .cards) ?? []
        newDay = try c.decodeIfPresent(String.self, forKey: .newDay) ?? ""
        newDone = try c.decodeIfPresent(Int.self, forKey: .newDone) ?? 0
        bundled = try c.decodeIfPresent(Bool.self, forKey: .bundled) ?? false
    }
}

struct StudySettings: Codable, Equatable {
    var newPerDay: Int = 20
    var reverse: Bool = false

    enum CodingKeys: String, CodingKey { case newPerDay, reverse }
}

extension StudySettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        newPerDay = try c.decodeIfPresent(Int.self, forKey: .newPerDay) ?? 20
        reverse = try c.decodeIfPresent(Bool.self, forKey: .reverse) ?? false
    }
}

/// The whole saved state. The same shape is used for backup files, so the
/// browser version can read and write it too.
struct AppData: Codable, Equatable {
    var format: String = "flashcards-backup-1"
    var exported: Date? = nil
    var decks: [Deck] = []
    var settings = StudySettings()
    var deletedIds: [String] = []   // card ids, or "deck:<id>", that must not come back

    enum CodingKeys: String, CodingKey { case format, exported, decks, settings, deletedIds }
}

extension AppData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? "flashcards-backup-1"
        exported = try c.decodeIfPresent(Date.self, forKey: .exported)
        decks = try c.decode([Deck].self, forKey: .decks)
        settings = try c.decodeIfPresent(StudySettings.self, forKey: .settings) ?? StudySettings()
        deletedIds = try c.decodeIfPresent([String].self, forKey: .deletedIds) ?? []
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Bundle {
    var versionString: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (build \(b))"
    }
}
