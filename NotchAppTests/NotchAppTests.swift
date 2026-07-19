import Foundation
import Testing
@testable import NotchApp

@MainActor
struct NotchShelfTests {
    @Test func clipboardDeduplicatesAndMovesExistingItemToFront() async throws {
        let store = ClipboardHistoryStore(store: try temporaryStore(), maxUnpinnedCount: 50)

        store.upsert("first", date: Date(timeIntervalSince1970: 1))
        store.upsert("second", date: Date(timeIntervalSince1970: 2))
        store.upsert("first", date: Date(timeIntervalSince1970: 3))

        #expect(store.items.count == 2)
        #expect(store.items[0].value == "first")
        #expect(store.items[0].lastCopiedAt == Date(timeIntervalSince1970: 3))
    }

    @Test func clipboardRetentionKeepsPinnedItems() async throws {
        let store = ClipboardHistoryStore(store: try temporaryStore(), maxUnpinnedCount: 2)

        store.upsert("pinned")
        let pinned = store.items[0]
        store.togglePin(pinned)
        store.upsert("one")
        store.upsert("two")
        store.upsert("three")

        #expect(store.items.contains { $0.value == "pinned" && $0.isPinned })
        #expect(store.items.filter { !$0.isPinned }.count == 2)
    }

    @Test func jsonStoreRoundTripsClipboardMetadata() throws {
        let store = try temporaryStore()
        let item = ClipboardHistoryItem(
            id: UUID(),
            kind: .link,
            value: "https://example.com",
            createdAt: Date(timeIntervalSince1970: 10),
            lastCopiedAt: Date(timeIntervalSince1970: 20),
            isPinned: true,
            title: "Example",
            favoriteFolder: "Links",
            contentHash: ClipboardHistoryStore.contentHash(for: "https://example.com")
        )

        try store.save([item], to: "clipboard.json")
        let loaded = store.load([ClipboardHistoryItem].self, from: "clipboard.json", default: [])

        #expect(loaded == [item])
    }

    @Test func clipboardFavoritesCanMoveBetweenFolders() async throws {
        let store = ClipboardHistoryStore(store: try temporaryStore(), maxUnpinnedCount: 50)

        store.upsert("favorite text")
        let item = store.items[0]
        store.setFavoriteFolder(item, folder: "Research")

        #expect(store.items[0].isPinned)
        #expect(store.items[0].favoriteFolder == "Research")
        #expect(store.favoriteFolders.contains("Research"))
    }

    @Test func clipboardFavoriteFoldersStartEmpty() async throws {
        let store = ClipboardHistoryStore(store: try temporaryStore(), maxUnpinnedCount: 50)

        #expect(store.favoriteFolders.isEmpty)
    }

    @Test func clipboardFavoriteFoldersCanBeDeleted() async throws {
        let store = ClipboardHistoryStore(store: try temporaryStore(), maxUnpinnedCount: 50)

        store.upsert("saved text")
        let item = store.items[0]
        store.setFavoriteFolder(item, folder: "Research")
        store.deleteFavoriteFolder("Research")

        #expect(store.favoriteFolders.isEmpty)
        #expect(store.items[0].value == "saved text")
        #expect(!store.items[0].isPinned)
        #expect(store.items[0].favoriteFolder == nil)
    }

    @Test func clipboardItemsCanStoreTitles() async throws {
        let store = ClipboardHistoryStore(store: try temporaryStore(), maxUnpinnedCount: 50)

        store.upsert("let title = searchable")
        let item = store.items[0]
        store.setTitle(item, title: "Snippet")

        #expect(store.items[0].title == "Snippet")
    }

    @Test func shelfCreatesUniqueDestinationNames() async throws {
        let store = ShelfStore(store: try temporaryStore())
        let source = try makeTemporaryFile(named: "note.txt", contents: "hello")

        let first = try store.addFile(from: source)
        let second = try store.addFile(from: source)

        #expect(first.storedPath != second.storedPath)
        #expect(FileManager.default.fileExists(atPath: first.storedPath))
        #expect(FileManager.default.fileExists(atPath: second.storedPath))
    }

    @Test func shelfRemoveDeletesOnlyStoredCopy() async throws {
        let store = ShelfStore(store: try temporaryStore())
        let source = try makeTemporaryFile(named: "remove.txt", contents: "keep source")
        let item = try store.addFile(from: source)

        store.remove(item)

        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(!FileManager.default.fileExists(atPath: item.storedPath))
        #expect(store.items.isEmpty)
    }

    @Test func shelfPurgesUnpinnedFilesAfterTwoDays() async throws {
        let store = ShelfStore(store: try temporaryStore())
        let source = try makeTemporaryFile(named: "old.txt", contents: "temporary")
        let oldDate = Date(timeIntervalSinceNow: -172_801)
        let item = try store.addFile(from: source, date: oldDate)

        store.purgeExpired(referenceDate: Date())

        #expect(!FileManager.default.fileExists(atPath: item.storedPath))
        #expect(store.items.isEmpty)
    }

    @Test func shelfKeepsPinnedFilesPastTwoDays() async throws {
        let store = ShelfStore(store: try temporaryStore())
        let source = try makeTemporaryFile(named: "pinned-old.txt", contents: "keep")
        let oldDate = Date(timeIntervalSinceNow: -172_801)
        let item = try store.addFile(from: source, date: oldDate)

        store.togglePin(item)
        store.purgeExpired(referenceDate: Date())

        #expect(FileManager.default.fileExists(atPath: item.storedPath))
        #expect(store.items.contains { $0.id == item.id && $0.isPinned })
    }

    @Test func quickNotesPersistLocally() async throws {
        let localStore = try temporaryStore()
        let notes = QuickNotesStore(store: localStore)

        notes.add("Remember this", date: Date(timeIntervalSince1970: 100))
        let reloaded = QuickNotesStore(store: localStore)

        #expect(reloaded.notes.count == 1)
        #expect(reloaded.notes[0].text == "Remember this")
    }

    @Test func mockCodexProviderTransitionsTasks() async throws {
        let provider = MockCodexTaskProvider()
        _ = try await provider.loadTasks()
        _ = try await provider.loadTasks()
        let third = try await provider.loadTasks()

        #expect(third.contains { $0.title == "NotchShelf build" && $0.status == .done })
    }

    private func temporaryStore() throws -> LocalJSONStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchShelfTests-\(UUID().uuidString)", isDirectory: true)
        let store = LocalJSONStore(rootURL: url)
        try store.prepareDirectories()
        return store
    }

    private func makeTemporaryFile(named name: String, contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchShelfSource-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try contents.data(using: .utf8)?.write(to: url)
        return url
    }
}
