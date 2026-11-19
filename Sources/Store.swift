import Foundation
import SwiftUI

private struct BundledDeckInfo: Codable {
    let id: String
    let name: String
    let file: String
}

struct UndoRecord {
    let deckId: String
    let previous: Card
    let wasNew: Bool
    let newDay: String
    let newDone: Int
}

@MainActor
final class Store: ObservableObject {
    @Published var data = AppData()
    @Published var currentDeckId: String? {
        didSet {
            UserDefaults.standard.set(currentDeckId, forKey: "currentDeck")
            tagFilter = "All"
            resetStudyCursor()
        }
    }
    @Published var tagFilter = "All" {
        didSet { if oldValue != tagFilter { resetStudyCursor() } }
    }
    @Published var currentCardId: String?
    @Published var revealed = false
    @Published var banner: String?
    @Published private(set) var lastAnswer: UndoRecord?

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("flashcards.json")
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        load()
        let result = mergeBundled()
        let saved = UserDefaults.standard.string(forKey: "currentDeck")
        if let saved, data.decks.contains(where: { $0.id == saved }) {
            currentDeckId = saved
        } else {
            currentDeckId = data.decks.first?.id
        }
        save()
        if result.added + result.updated > 0 && result.hadExisting {
            var parts: [String] = []
            if result.added > 0 { parts.append("\(result.added) new card\(result.added == 1 ? "" : "s")") }
            if result.updated > 0 { parts.append("\(result.updated) updated") }
            banner = "Deck update: " + parts.joined(separator: ", ")
        }
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let raw = try Data(contentsOf: fileURL)
            data = try Store.decoder.decode(AppData.self, from: raw)
        } catch {
            // Keep the unreadable file instead of overwriting it.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingLastPathComponent().appendingPathComponent("flashcards-unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            banner = "Saved data couldn't be read; it was kept as a backup file."
        }
    }

    func save() {
        do {
            let raw = try Store.encoder.encode(data)
            try raw.write(to: fileURL, options: .atomic)
        } catch {
            banner = "Couldn't save: \(error.localizedDescription)"
        }
    }

    // MARK: - Bundled decks

    /// Adds new bundled cards and refreshes text you haven't edited. Progress is never touched.
    private func mergeBundled() -> (added: Int, updated: Int, hadExisting: Bool) {
        let hadExisting = !data.decks.isEmpty
        guard let url = Bundle.main.url(forResource: "decks", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let infos = try? JSONDecoder().decode([BundledDeckInfo].self, from: raw) else {
            return (0, 0, hadExisting)
        }
        let deleted = Set(data.deletedIds)
        var added = 0, updated = 0
        let now = Date()
        for info in infos {
            if deleted.contains("deck:" + info.id) { continue }
            let lines = bundledCards(file: info.file)
            if let di = data.decks.firstIndex(where: { $0.id == info.id }) {
                for b in lines where !deleted.contains(b.id) {
                    if let ci = data.decks[di].cards.firstIndex(where: { $0.id == b.id }) {
                        var c = data.decks[di].cards[ci]
                        if !c.userEdited && (c.front != b.front || c.back != b.back || c.tag != b.tag) {
                            c.front = b.front; c.back = b.back; c.tag = b.tag; c.modified = now
                            data.decks[di].cards[ci] = c
                            updated += 1
                        }
                    } else {
                        data.decks[di].cards.append(b)
                        added += 1
                    }
                }
            } else {
                let deck = Deck(id: info.id, name: info.name, created: now,
                                cards: lines.filter { !deleted.contains($0.id) }, bundled: true)
                data.decks.append(deck)
                added += deck.cards.count
            }
        }
        return (added, updated, hadExisting)
    }

    private func bundledCards(file: String) -> [Card] {
        guard let url = Bundle.main.url(forResource: file, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line -> Card? in
            let s = String(line)
            if s.hasPrefix("#") || s.trimmed.isEmpty { return nil }
            let p = s.components(separatedBy: "|")
            guard p.count >= 3 else { return nil }
            return Card(id: p[0].trimmed, front: p[1].trimmed, back: p[2].trimmed, tag: p.count > 3 ? p[3].trimmed : "")
        }
    }

    // MARK: - Lookup

    var currentDeck: Deck? {
        guard let id = currentDeckId else { return nil }
        return data.decks.first { $0.id == id }
    }

    private func deckIndex(_ id: String) -> Int? { data.decks.firstIndex { $0.id == id } }

    func card(_ cardId: String, in deckId: String) -> Card? {
        data.decks.first(where: { $0.id == deckId })?.cards.first(where: { $0.id == cardId })
    }

    func tags(in deck: Deck) -> [String] {
        Array(Set(deck.cards.map(\.tag).filter { !$0.isEmpty })).sorted()
    }

    // MARK: - Study queue

    func pool(_ d: Deck) -> [Card] {
        tagFilter == "All" ? d.cards : d.cards.filter { $0.tag == tagFilter }
    }

    func newLeft(_ d: Deck) -> Int {
        let limit = data.settings.newPerDay
        return d.newDay != Scheduler.dayKey() ? limit : max(0, limit - d.newDone)
    }

    struct Counts { var new = 0, learning = 0, review = 0, newTotal = 0 }

    func counts(_ d: Deck, now: Date = Date()) -> Counts {
        let p = pool(d)
        let end = Scheduler.addDays(1, to: now)
        let newTotal = p.filter { $0.state == .new }.count
        return Counts(
            new: min(newTotal, newLeft(d)),
            learning: p.filter { ($0.state == .learning || $0.state == .relearning) && $0.due < end }.count,
            review: p.filter { $0.state == .review && $0.due <= now }.count,
            newTotal: newTotal)
    }

    func pick(_ d: Deck, now: Date = Date()) -> Card? {
        let p = pool(d)
        let learning = p.filter { $0.state == .learning || $0.state == .relearning }
        if let c = learning.filter({ $0.due <= now }).min(by: { $0.due < $1.due }) { return c }
        if let c = p.filter({ $0.state == .review && $0.due <= now }).min(by: { $0.due < $1.due }) { return c }
        if newLeft(d) > 0, let c = p.first(where: { $0.state == .new }) { return c }
        return learning.filter { $0.due <= now.addingTimeInterval(20 * 60) }.min(by: { $0.due < $1.due })
    }

    var displayedCard: Card? {
        guard let d = currentDeck, let id = currentCardId else { return nil }
        return d.cards.first { $0.id == id }
    }

    func advanceIfNeeded() {
        guard displayedCard == nil else { return }
        let next = currentDeck.flatMap { pick($0) }
        if next?.id != currentCardId { currentCardId = next?.id }
        revealed = false
    }

    func resetStudyCursor() {
        currentCardId = nil
        revealed = false
        advanceIfNeeded()
    }

    func answer(_ r: Rating) {
        guard revealed, let deckId = currentDeckId, let di = deckIndex(deckId),
              let card = displayedCard,
              let ci = data.decks[di].cards.firstIndex(where: { $0.id == card.id }) else { return }
        let wasNew = card.state == .new
        lastAnswer = UndoRecord(deckId: deckId, previous: card, wasNew: wasNew,
                                newDay: data.decks[di].newDay, newDone: data.decks[di].newDone)
        data.decks[di].cards[ci] = Scheduler.answer(card, r)
        if wasNew {
            let today = Scheduler.dayKey()
            if data.decks[di].newDay != today { data.decks[di].newDay = today; data.decks[di].newDone = 0 }
            data.decks[di].newDone += 1
        }
        currentCardId = nil
        revealed = false
        advanceIfNeeded()
        save()
    }

    func undo() {
        guard let u = lastAnswer, let di = deckIndex(u.deckId),
              let ci = data.decks[di].cards.firstIndex(where: { $0.id == u.previous.id }) else { return }
        data.decks[di].cards[ci] = u.previous
        if u.wasNew { data.decks[di].newDay = u.newDay; data.decks[di].newDone = u.newDone }
        if currentDeckId != u.deckId { currentDeckId = u.deckId }
        currentCardId = u.previous.id
        revealed = true
        lastAnswer = nil
        save()
    }

    func studyMoreNew() {
        guard let id = currentDeckId, let di = deckIndex(id) else { return }
        let today = Scheduler.dayKey()
        if data.decks[di].newDay != today { data.decks[di].newDay = today; data.decks[di].newDone = 0 }
        data.decks[di].newDone -= max(data.settings.newPerDay, 10)
        resetStudyCursor()
        save()
    }

    // MARK: - Editing

    func editCard(_ cardId: String, in deckId: String, front: String, back: String, tag: String) {
        guard let di = deckIndex(deckId), let ci = data.decks[di].cards.firstIndex(where: { $0.id == cardId }) else { return }
        var c = data.decks[di].cards[ci]
        c.front = front.trimmed; c.back = back.trimmed; c.tag = tag.trimmed
        c.modified = Date(); c.userEdited = true
        data.decks[di].cards[ci] = c
        save()
        banner = "Saved"
    }

    func resetCard(_ cardId: String, in deckId: String) {
        guard let di = deckIndex(deckId), let ci = data.decks[di].cards.firstIndex(where: { $0.id == cardId }) else { return }
        data.decks[di].cards[ci].resetProgress()
        save()
        banner = "Progress reset"
    }

    func deleteCard(_ cardId: String, in deckId: String) {
        guard let di = deckIndex(deckId) else { return }
        data.decks[di].cards.removeAll { $0.id == cardId }
        if !data.deletedIds.contains(cardId) { data.deletedIds.append(cardId) }
        if currentCardId == cardId { resetStudyCursor() }
        save()
        banner = "Card deleted"
    }

    func addCard(front: String, back: String, tag: String, to deckId: String) {
        guard let di = deckIndex(deckId) else { return }
        var c = Card(id: UUID().uuidString, front: front.trimmed, back: back.trimmed, tag: tag.trimmed)
        c.modified = Date()
        data.decks[di].cards.append(c)
        advanceIfNeeded()
        save()
        banner = "Card added"
    }

    /// One card per line: term and meaning separated by a tab, ";" or " = ". Optional third field is the tag.
    func importText(_ text: String, into deckId: String) -> String {
        guard let di = deckIndex(deckId) else { return "No deck selected" }
        var have = Set(data.decks[di].cards.map { $0.front.lowercased() })
        var added = 0, dup = 0, bad = 0
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmed
            if line.isEmpty { continue }
            let parts: [String]
            if line.contains("\t") { parts = line.components(separatedBy: "\t") }
            else if line.contains(";") { parts = line.components(separatedBy: ";") }
            else if line.contains(" = ") { parts = line.components(separatedBy: " = ") }
            else { bad += 1; continue }
            guard parts.count >= 2, !parts[0].trimmed.isEmpty, !parts[1].trimmed.isEmpty else { bad += 1; continue }
            let front = parts[0].trimmed
            if have.contains(front.lowercased()) { dup += 1; continue }
            var c = Card(id: UUID().uuidString, front: front, back: parts[1].trimmed, tag: parts.count > 2 ? parts[2].trimmed : "")
            c.modified = Date()
            data.decks[di].cards.append(c)
            have.insert(front.lowercased())
            added += 1
        }
        if added > 0 { advanceIfNeeded(); save() }
        var msg = "Added \(added)"
        if dup > 0 { msg += " · \(dup) already in deck" }
        if bad > 0 { msg += " · \(bad) lines unreadable" }
        return msg
    }

    // MARK: - Decks & settings

    func newDeck(_ name: String) {
        let deck = Deck(id: "d-" + UUID().uuidString.prefix(8).lowercased(), name: name.trimmed)
        data.decks.append(deck)
        save()
        currentDeckId = deck.id
    }

    func renameDeck(_ id: String, to name: String) {
        guard let di = deckIndex(id), !name.trimmed.isEmpty, data.decks[di].name != name.trimmed else { return }
        data.decks[di].name = name.trimmed
        save()
    }

    func deleteDeck(_ id: String) {
        data.decks.removeAll { $0.id == id }
        data.deletedIds.append("deck:" + id)
        lastAnswer = nil
        save()
        currentDeckId = data.decks.first?.id
    }

    func setNewPerDay(_ n: Int) {
        data.settings.newPerDay = max(0, min(500, n))
        save()
        advanceIfNeeded()
    }

    func setReverse(_ on: Bool) {
        data.settings.reverse = on
        save()
    }

    // MARK: - Backup & sync

    func exportFile() throws -> URL {
        var copy = data
        copy.exported = Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HHmm"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Flashcards backup \(f.string(from: Date())).json")
        try Store.encoder.encode(copy).write(to: url, options: .atomic)
        return url
    }

    func importFile(_ url: URL) -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let raw = try? Data(contentsOf: url) else { return "Couldn't open that file" }
        if let incoming = try? Store.decoder.decode(AppData.self, from: raw) {
            return merge(incoming)
        }
        if let text = String(data: raw, encoding: .utf8), let id = currentDeckId {
            return importText(text, into: id)
        }
        return "That file isn't a flashcards backup or a text list"
    }

    /// Card-by-card merge: newer review progress wins, newer text edits win,
    /// missing cards are added, nothing is deleted.
    func merge(_ incoming: AppData) -> String {
        let deleted = Set(data.deletedIds)
        let today = Scheduler.dayKey()
        var added = 0, progressed = 0, edited = 0, decksAdded = 0
        for inDeck in incoming.decks {
            if deleted.contains("deck:" + inDeck.id) { continue }
            guard let di = deckIndex(inDeck.id) else {
                var d = inDeck
                d.cards.removeAll { deleted.contains($0.id) }
                data.decks.append(d)
                decksAdded += 1
                added += d.cards.count
                continue
            }
            for ic in inDeck.cards where !deleted.contains(ic.id) {
                if let ci = data.decks[di].cards.firstIndex(where: { $0.id == ic.id }) {
                    var lc = data.decks[di].cards[ci]
                    if (ic.lastReviewed ?? epoch) > (lc.lastReviewed ?? epoch) {
                        lc.applyProgress(from: ic)
                        progressed += 1
                    }
                    if ic.modified > lc.modified && (ic.front != lc.front || ic.back != lc.back || ic.tag != lc.tag) {
                        lc.front = ic.front; lc.back = ic.back; lc.tag = ic.tag
                        lc.modified = ic.modified
                        lc.userEdited = lc.userEdited || ic.userEdited
                        edited += 1
                    }
                    data.decks[di].cards[ci] = lc
                } else {
                    data.decks[di].cards.append(ic)
                    added += 1
                }
            }
            if inDeck.newDay == data.decks[di].newDay {
                data.decks[di].newDone = max(data.decks[di].newDone, inDeck.newDone)
            } else if inDeck.newDay == today {
                data.decks[di].newDay = inDeck.newDay
                data.decks[di].newDone = inDeck.newDone
            }
        }
        if currentDeckId == nil { currentDeckId = data.decks.first?.id }
        resetStudyCursor()
        save()
        var parts = ["\(progressed) cards' progress updated", "\(added) added"]
        if edited > 0 { parts.append("\(edited) edited") }
        if decksAdded > 0 { parts.append("\(decksAdded) new deck\(decksAdded == 1 ? "" : "s")") }
        return "Imported: " + parts.joined(separator: ", ")
    }
}
