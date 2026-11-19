import SwiftUI

struct CardsView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if let deck = store.currentDeck {
                    let cards = deck.cards.filter {
                        query.isEmpty || "\($0.front) \($0.back) \($0.tag)".localizedCaseInsensitiveContains(query)
                    }
                    List(cards) { c in
                        NavigationLink(value: c.id) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(c.front).font(.system(.body, design: .serif).weight(.semibold))
                                Text(c.back).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                Text([c.tag, Scheduler.dueText(c)].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .overlay {
                        if cards.isEmpty { ContentUnavailableView.search(text: query) }
                    }
                    .navigationDestination(for: String.self) { id in
                        EditCardView(deckId: deck.id, cardId: id)
                    }
                } else {
                    ContentUnavailableView("No deck selected", systemImage: "rectangle.stack")
                }
            }
            .searchable(text: $query, prompt: "Term, meaning or tag")
            .navigationTitle(store.currentDeck.map { "\($0.name) (\($0.cards.count))" } ?? "Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { DeckMenu() } }
        }
    }
}

struct EditCardView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let deckId: String
    let cardId: String

    @State private var front = ""
    @State private var back = ""
    @State private var tag = ""
    @State private var loaded = false
    @State private var confirmDelete = false

    private var card: Card? { store.card(cardId, in: deckId) }

    var body: some View {
        Form {
            if let card {
                Section("Card") {
                    TextField("Term", text: $front, axis: .vertical)
                    TextField("Meaning", text: $back, axis: .vertical)
                    TextField("Tag", text: $tag)
                }
                Section("Progress") {
                    LabeledContent("Status", value: Scheduler.dueText(card))
                    if card.state == .review {
                        LabeledContent("Interval", value: Scheduler.formatDays(card.interval))
                    }
                    LabeledContent("Reviews", value: "\(card.reps)")
                    LabeledContent("Forgotten", value: "\(card.lapses)×")
                    LabeledContent("Ease", value: String(format: "%.2f", card.ease))
                }
                Section {
                    Button("Reset progress") { store.resetCard(cardId, in: deckId) }
                    Button("Delete card", role: .destructive) { confirmDelete = true }
                }
            } else {
                Text("This card no longer exists.")
            }
        }
        .navigationTitle("Edit card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.editCard(cardId, in: deckId, front: front, back: back, tag: tag)
                    dismiss()
                }
                .disabled(front.trimmed.isEmpty || back.trimmed.isEmpty || card == nil)
            }
        }
        .onAppear {
            if !loaded, let c = card {
                front = c.front; back = c.back; tag = c.tag
                loaded = true
            }
        }
        .confirmationDialog("Delete this card and its progress?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.deleteCard(cardId, in: deckId)
                dismiss()
            }
        }
    }
}
