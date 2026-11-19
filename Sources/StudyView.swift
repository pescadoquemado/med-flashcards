import SwiftUI
import UIKit

struct StudyView: View {
    @EnvironmentObject var store: Store
    private let tick = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let deck = store.currentDeck {
                        TagChips(tags: store.tags(in: deck), selection: $store.tagFilter)
                        if let card = store.displayedCard {
                            IndexCardView(card: card, caption: card.tag.isEmpty ? deck.name : card.tag,
                                          revealed: store.revealed, reverse: store.data.settings.reverse)
                                .onTapGesture { reveal() }
                            if store.revealed {
                                RatingBar(card: card)
                            } else {
                                Button(action: reveal) {
                                    Text("Show answer")
                                        .font(.headline)
                                        .foregroundStyle(Theme.teal)
                                        .frame(maxWidth: .infinity, minHeight: 56)
                                        .background(Theme.cardBG, in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            CaughtUpView(deck: deck)
                        }
                        if store.lastAnswer != nil {
                            Button("Undo last answer") { store.undo() }
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(minHeight: 44)
                        }
                    } else {
                        ContentUnavailableView("No decks", systemImage: "rectangle.stack",
                                               description: Text("Create a deck in Settings."))
                            .foregroundStyle(.white)
                    }
                }
                .padding()
            }
            .background(Theme.teal.ignoresSafeArea())
            .navigationTitle(store.currentDeck?.name ?? "Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.teal, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { DeckMenu().tint(.white) }
                ToolbarItem(placement: .topBarTrailing) { CountsView() }
            }
            .onAppear { store.advanceIfNeeded() }
            .onReceive(tick) { _ in store.advanceIfNeeded() }
        }
    }

    private func reveal() {
        guard !store.revealed else { return }
        withAnimation(.easeOut(duration: 0.2)) { store.revealed = true }
    }
}

struct CountsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        if let deck = store.currentDeck {
            let c = store.counts(deck)
            HStack(spacing: 10) {
                Text("\(c.new)").foregroundStyle(Theme.countNew)
                Text("\(c.learning)").foregroundStyle(Theme.countLearn)
                Text("\(c.review)").foregroundStyle(Theme.countDue)
            }
            .font(.headline.monospacedDigit())
            .accessibilityLabel("\(c.new) new, \(c.learning) learning, \(c.review) due")
        }
    }
}

struct TagChips: View {
    let tags: [String]
    @Binding var selection: String

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["All"] + tags, id: \.self) { tag in
                        let on = tag == selection
                        Button { selection = tag } label: {
                            Text(tag)
                                .font(.subheadline.weight(on ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .frame(minHeight: 34)
                                .foregroundStyle(on ? Theme.teal : Color.white)
                                .background(on ? Color.white : Color.white.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// The ruled index card.
struct IndexCardView: View {
    let card: Card
    let caption: String
    let revealed: Bool
    let reverse: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(caption)
                Spacer()
                Text(card.state.label)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)

            Rectangle().fill(Theme.red).frame(height: 2)

            VStack(spacing: 18) {
                Text(reverse ? card.back : card.front)
                    .font(.system(size: 38, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                if revealed {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(height: 1)
                        .padding(.horizontal, 40)
                    Text(reverse ? card.front : card.back)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .padding(.vertical, 24)
            .background(RuledLines())
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Theme.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 12)
        .contentShape(Rectangle())
    }
}

struct RuledLines: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var y: CGFloat = 40
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += 40
            }
            ctx.stroke(path, with: .color(Theme.rule), lineWidth: 1)
        }
    }
}

struct RatingBar: View {
    @EnvironmentObject var store: Store
    let card: Card

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Rating.allCases) { r in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.15)) { store.answer(r) }
                } label: {
                    VStack(spacing: 2) {
                        Text(r.title).font(.headline)
                        Text(Scheduler.label(card, r)).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(Theme.cardBG)
                    .overlay(alignment: .top) { Rectangle().fill(r.color).frame(height: 5) }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CaughtUpView: View {
    @EnvironmentObject var store: Store
    let deck: Deck

    var body: some View {
        let c = store.counts(deck)
        VStack(spacing: 12) {
            Text("All caught up")
                .font(.system(size: 30, weight: .semibold, design: .serif))
            Text(nextMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if c.newTotal > 0 {
                Button("Study \(min(c.newTotal, max(store.data.settings.newPerDay, 10))) more new cards") {
                    store.studyMoreNew()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(24)
        .background(Theme.cardBG, in: RoundedRectangle(cornerRadius: 6))
    }

    private var nextMessage: String {
        let p = store.pool(deck)
        let now = Date()
        if let next = p.filter({ $0.state == .learning || $0.state == .relearning }).min(by: { $0.due < $1.due }) {
            return "Next learning card in \(Scheduler.formatMinutes(next.due.timeIntervalSince(now)))."
        }
        let tomorrowEnd = Scheduler.addDays(2, to: now)
        let n = p.filter { $0.state == .review && $0.due < tomorrowEnd }.count
        return n > 0 ? "\(n) review\(n == 1 ? "" : "s") due tomorrow." : "Nothing else is due soon."
    }
}
