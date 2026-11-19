import SwiftUI

@main
struct FlashcardsApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Theme.teal)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        TabView {
            StudyView()
                .tabItem { Label("Study", systemImage: "rectangle.on.rectangle.angled") }
            CardsView()
                .tabItem { Label("Cards", systemImage: "list.bullet.rectangle") }
            AddView()
                .tabItem { Label("Add", systemImage: "plus.rectangle.on.rectangle") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .overlay(alignment: .bottom) {
            if let message = store.banner {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.82), in: Capsule())
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.banner)
        .task(id: store.banner) {
            guard store.banner != nil else { return }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            store.banner = nil
        }
    }
}

/// Deck switcher shown in every tab's toolbar.
struct DeckMenu: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Menu {
            Picker("Deck", selection: Binding(
                get: { store.currentDeckId ?? "" },
                set: { store.currentDeckId = $0 })) {
                ForEach(store.data.decks) { deck in
                    Text(deck.name).tag(deck.id)
                }
            }
        } label: {
            Image(systemName: "rectangle.stack")
                .accessibilityLabel("Choose deck")
        }
    }
}
