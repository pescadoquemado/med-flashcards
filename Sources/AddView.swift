import SwiftUI

struct AddView: View {
    @EnvironmentObject var store: Store
    @State private var front = ""
    @State private var back = ""
    @State private var tag = ""
    @State private var bulk = ""
    @FocusState private var termFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                if let deck = store.currentDeck {
                    Section {
                        TextField("Term", text: $front).focused($termFocused)
                        TextField("Meaning", text: $back, axis: .vertical)
                        TextField("Tag (optional)", text: $tag)
                        Button("Add card") {
                            store.addCard(front: front, back: back, tag: tag, to: deck.id)
                            front = ""; back = ""
                            termFocused = true
                        }
                        .disabled(front.trimmed.isEmpty || back.trimmed.isEmpty)
                    } header: {
                        Text("Add to \(deck.name)")
                    }

                    Section {
                        TextEditor(text: $bulk)
                            .font(.system(.callout, design: .monospaced))
                            .frame(minHeight: 160)
                        Button("Import cards") {
                            store.banner = store.importText(bulk, into: deck.id)
                            bulk = ""
                        }
                        .disabled(bulk.trimmed.isEmpty)
                    } header: {
                        Text("Paste many")
                    } footer: {
                        Text("One card per line: term, then meaning, separated by a tab, a semicolon, or \" = \". An optional third field is the tag. Quizlet and Anki text exports paste straight in.")
                    }
                } else {
                    Text("Create a deck in Settings first.")
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { DeckMenu() } }
        }
    }
}
