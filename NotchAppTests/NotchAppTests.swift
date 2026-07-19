import AppKit
import Foundation
import SwiftUI
import Testing
@testable import NotchApp

@MainActor
struct NotchShelfTests {
    @Test func closingKeepsTheExpandedShellUntilTheFrameSettles() {
        let chrome = NotchChromeModel()

        chrome.open()
        chrome.completeFrameTransition(towardOpen: true)
        chrome.close()

        #expect(!chrome.isOpen)
        #expect(!chrome.showsOpenContent)
        #expect(chrome.usesExpandedAppearance)
        #expect(chrome.isTransitioning)

        chrome.completeFrameTransition(towardOpen: false)

        #expect(!chrome.usesExpandedAppearance)
        #expect(!chrome.isTransitioning)
    }

    @Test func reopeningIgnoresAStaleClosingCompletion() {
        let chrome = NotchChromeModel()

        chrome.open()
        chrome.close()
        chrome.open()
        chrome.completeFrameTransition(towardOpen: false)

        #expect(chrome.isOpen)
        #expect(chrome.showsOpenContent)
        #expect(chrome.usesExpandedAppearance)
        #expect(chrome.isTransitioning)

        chrome.completeFrameTransition(towardOpen: true)

        #expect(!chrome.isTransitioning)
    }

    @Test func expandedShellFlowsInFromTheTopBezel() {
        let path = NotchBezelShellShape(
            notchWidth: 185,
            notchHeight: 32,
            bezelShoulderRadius: 28,
            bezelShoulderDepth: 30,
            bottomCornerRadius: 30
        )
        .path(in: CGRect(x: 0, y: 0, width: 560, height: 408))

        #expect(path.contains(CGPoint(x: 280, y: 4)))
        #expect(!path.contains(CGPoint(x: 8, y: 4)))
        #expect(path.contains(CGPoint(x: 20, y: 4)))
        #expect(!path.contains(CGPoint(x: 10, y: 40)))
        #expect(path.contains(CGPoint(x: 28, y: 40)))
        #expect(!path.contains(CGPoint(x: 4, y: 72)))
        #expect(path.contains(CGPoint(x: 30, y: 72)))
    }

    @Test func expandedShellUsesRoundedHooksBelowTheBezel() {
        let path = NotchBezelShellShape(
            notchWidth: 185,
            notchHeight: 32,
            bezelShoulderRadius: 28,
            bezelShoulderDepth: 30,
            bottomCornerRadius: 30
        )
        .path(in: CGRect(x: 0, y: 0, width: 560, height: 408))

        #expect(!path.contains(CGPoint(x: 8, y: 4)))
        #expect(path.contains(CGPoint(x: 20, y: 4)))
        #expect(!path.contains(CGPoint(x: 20, y: 12)))
        #expect(path.contains(CGPoint(x: 27, y: 12)))
        #expect(!path.contains(CGPoint(x: 24, y: 24)))
        #expect(path.contains(CGPoint(x: 30, y: 24)))
    }

    @Test func shellShouldersGrowProgressivelyDuringWindowResize() {
        let path = NotchBezelShellShape(
            notchWidth: 185,
            notchHeight: 32,
            bezelShoulderRadius: 28,
            bezelShoulderDepth: 30,
            bottomCornerRadius: 30
        )
        .path(in: CGRect(x: 0, y: 0, width: 220, height: 40))

        #expect(path.contains(CGPoint(x: 110, y: 38)))
        #expect(path.contains(CGPoint(x: 20, y: 38)))
        #expect(!path.contains(CGPoint(x: 4, y: 38)))
    }

    @Test func expandedPanelKeepsOpenWhenPointerLeavesTheOriginalNotchArea() {
        let shouldKeepOpen = NotchPointerInteraction.shouldKeepOpen(
            panelFrame: NSRect(x: 476, y: 574, width: 560, height: 408),
            isKeyWindow: false,
            mouseLocation: NSPoint(x: 650, y: 850)
        )

        #expect(shouldKeepOpen)
    }

    @Test func interactingPanelStaysOpenOutsideItsBoundsWhileKey() {
        let shouldKeepOpen = NotchPointerInteraction.shouldKeepOpen(
            panelFrame: NSRect(x: 476, y: 574, width: 560, height: 408),
            isKeyWindow: true,
            mouseLocation: NSPoint(x: 200, y: 200)
        )

        #expect(shouldKeepOpen)
    }

    @Test func inactivePanelCanDismissAfterPointerLeaves() {
        let shouldKeepOpen = NotchPointerInteraction.shouldKeepOpen(
            panelFrame: NSRect(x: 476, y: 574, width: 560, height: 408),
            isKeyWindow: false,
            mouseLocation: NSPoint(x: 200, y: 200)
        )

        #expect(!shouldKeepOpen)
    }

    @Test func cameraHousingGeometryUsesTheGapBetweenAuxiliaryAreas() {
        let housingFrame = NotchScreenGeometry.cameraHousingFrame(
            screenFrame: NSRect(x: 0, y: 0, width: 1_512, height: 982),
            safeAreaTop: 32,
            leftArea: NSRect(x: 0, y: 950, width: 663, height: 32),
            rightArea: NSRect(x: 848, y: 950, width: 664, height: 32)
        )

        #expect(housingFrame == NSRect(x: 663, y: 950, width: 185, height: 32))
    }

    @Test func cameraHousingGeometryFallsBackWhenTheScreenHasNoTopInset() {
        let housingFrame = NotchScreenGeometry.cameraHousingFrame(
            screenFrame: NSRect(x: 0, y: 0, width: 1_920, height: 1_080),
            safeAreaTop: 0,
            leftArea: nil,
            rightArea: nil
        )

        #expect(housingFrame == nil)
    }

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
