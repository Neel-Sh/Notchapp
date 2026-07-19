import AppKit
import Combine
import Foundation

@MainActor
final class QuickNotesStore: ObservableObject {
    @Published private(set) var notes: [QuickNoteItem]

    private let store: LocalJSONStore

    init(store: LocalJSONStore) {
        self.store = store
        self.notes = store.load([QuickNoteItem].self, from: "notes.json", default: [])
    }

    func add(_ text: String, date: Date = Date()) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        notes.insert(
            QuickNoteItem(id: UUID(), text: normalized, createdAt: date, updatedAt: date),
            at: 0
        )
        persist()
    }

    func update(_ note: QuickNoteItem, text: String, date: Date = Date()) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }

        if normalized.isEmpty {
            notes.remove(at: index)
        } else {
            notes[index].text = normalized
            notes[index].updatedAt = date
        }
        persist()
    }

    func delete(_ note: QuickNoteItem) {
        notes.removeAll { $0.id == note.id }
        persist()
    }

    func copy(_ note: QuickNoteItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(note.text, forType: .string)
    }

    private func persist() {
        do {
            try store.save(notes, to: "notes.json")
        } catch {
            NSLog("NotchShelf notes persistence failed: \(error.localizedDescription)")
        }
    }
}
