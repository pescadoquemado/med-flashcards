import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var deckName = ""
    @State private var newDeckName = ""
    @State private var confirmDeleteDeck = false
    @State private var showImporter = false
    @State private var share: ShareItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Study") {
                    Stepper(value: Binding(get: { store.data.settings.newPerDay },
                                           set: { store.setNewPerDay($0) }),
                            in: 0...500, step: 5) {
                        LabeledContent("New cards per day", value: "\(store.data.settings.newPerDay)")
                    }
                    Toggle("Show meaning first", isOn: Binding(get: { store.data.settings.reverse },
                                                               set: { store.setReverse($0) }))
                }

                if let deck = store.currentDeck {
                    Section("This deck") {
                        TextField("Deck name", text: $deckName)
                            .onSubmit { store.renameDeck(deck.id, to: deckName) }
                        LabeledContent("Cards", value: "\(deck.cards.count)")
                        Button("Delete deck", role: .destructive) { confirmDeleteDeck = true }
                    }
                }

                Section("New deck") {
                    TextField("Name, e.g. Body systems", text: $newDeckName)
                    Button("Create deck") {
                        store.newDeck(newDeckName)
                        newDeckName = ""
                    }
                    .disabled(newDeckName.trimmed.isEmpty)
                }

                Section {
                    Button("Export backup…") {
                        do { share = ShareItem(url: try store.exportFile()) }
                        catch { store.banner = "Export failed: \(error.localizedDescription)" }
                    }
                    Button("Import backup or text list…") { showImporter = true }
                } header: {
                    Text("Backup & sync")
                } footer: {
                    Text("Export saves every deck and all progress to a file you can AirDrop or keep in Files. Import merges card by card: the more recently reviewed progress wins, new cards are added, and nothing is deleted.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.versionString)
                } header: {
                    Text("About")
                } footer: {
                    Text("Scheduling works like Anki: new cards repeat at 1 and 10 minutes, then graduate to 1 day (4 with Easy); Good multiplies the interval by the card's ease. Starter decks were written by Claude. The simulation deck's doses come from the 2025 AHA/AAP PALS algorithms and its terms are paraphrased from the SSH/AHRQ Healthcare Simulation Dictionary and INACSL standards. These are study cards, not a clinical reference.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { DeckMenu() } }
            .onAppear { deckName = store.currentDeck?.name ?? "" }
            .onChange(of: store.currentDeckId) { _, _ in deckName = store.currentDeck?.name ?? "" }
            .onDisappear {
                if let id = store.currentDeckId { store.renameDeck(id, to: deckName) }
            }
            .confirmationDialog("Delete “\(store.currentDeck?.name ?? "")” and all its progress?",
                                isPresented: $confirmDeleteDeck, titleVisibility: .visible) {
                Button("Delete deck", role: .destructive) {
                    if let id = store.currentDeckId { store.deleteDeck(id) }
                }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json, .plainText, .commaSeparatedText, .tabSeparatedText]) { result in
                switch result {
                case .success(let url): store.banner = store.importFile(url)
                case .failure(let error): store.banner = "Import failed: \(error.localizedDescription)"
                }
            }
            .sheet(item: $share) { item in
                ActivityView(items: [item.url])
                    .presentationDetents([.medium, .large])
            }
        }
    }
}
