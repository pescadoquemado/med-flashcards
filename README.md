# Flashcards (medical terminology + simulation)

A personal Anki-style flashcard app for iPhone, built with SwiftUI. Every push to `main`
builds an **unsigned** `.ipa` on GitHub Actions and publishes it as a release, ready to
sign and install with Feather.

**Latest build:** Releases → newest `build-N` → `Flashcards.ipa`
(stable link: `https://github.com/<owner>/<repo>/releases/latest/download/Flashcards.ipa`)

## Updating cards
Decks live in `Resources/Decks/` as plain text, one card per line:

```
id|front|back|tag
```

- Keep existing `id`s unchanged; give new cards new ids (e.g. `mt-118`).
- On launch the app adds new cards and refreshes text of cards you haven't edited
  yourself. Study progress is never touched.
- Add a whole new bundled deck by adding a `.txt` file and an entry in `decks.json`.

## Backup & sync
Settings → Export backup writes a JSON file (`flashcards-backup-1` format).
Import merges card by card: newer review progress wins, newer text edits win, missing
cards are added, nothing is deleted. The browser version will use the same format.

## Build locally (optional)
```
brew install xcodegen && xcodegen generate && open Flashcards.xcodeproj
```
