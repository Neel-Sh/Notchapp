import AppKit
import Combine
import CryptoKit
import Foundation

@MainActor
final class ClipboardHistoryStore: NSObject, ObservableObject {
    @Published private(set) var items: [ClipboardHistoryItem]
    @Published private(set) var favoriteFolders: [String]

    private let store: LocalJSONStore
    private let maxUnpinnedCount: Int
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var ignoreNextChange = false
    private var timer: Timer?

    init(store: LocalJSONStore, maxUnpinnedCount: Int = 50) {
        self.store = store
        self.maxUnpinnedCount = maxUnpinnedCount
        self.items = store.load([ClipboardHistoryItem].self, from: "clipboard.json", default: [])
        let savedFolders = store.load([String].self, from: "clipboard-folders.json", default: [])
        self.favoriteFolders = Self.normalizedFolders(savedFolders)
        super.init()
    }

    func startMonitoring(interval: TimeInterval = 0.45) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(pasteboardTimerFired), userInfo: nil, repeats: true)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        guard let value = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return
        }

        upsert(value)
    }

    func upsert(_ value: String, date: Date = Date()) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        let hash = Self.contentHash(for: normalized)
        let kind: ClipboardKind = Self.looksLikeLink(normalized) ? .link : .text

        if let index = items.firstIndex(where: { $0.contentHash == hash }) {
            var item = items.remove(at: index)
            item.lastCopiedAt = date
            item.kind = kind
            items.insert(item, at: 0)
        } else {
            items.insert(
                ClipboardHistoryItem(
                    id: UUID(),
                    kind: kind,
                    value: normalized,
                    createdAt: date,
                    lastCopiedAt: date,
                    isPinned: false,
                    title: nil,
                    favoriteFolder: nil,
                    contentHash: hash
                ),
                at: 0
            )
        }

        trim()
        persist()
    }

    func copyBack(_ item: ClipboardHistoryItem) {
        ignoreNextChange = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.value, forType: .string)
        lastChangeCount = pasteboard.changeCount
        upsert(item.value)
    }

    func togglePin(_ item: ClipboardHistoryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        if !items[index].isPinned {
            items[index].favoriteFolder = nil
        }
        trim()
        persist()
    }

    func setFavoriteFolder(_ item: ClipboardHistoryItem, folder: String) {
        let normalized = Self.normalizedFolderName(folder)
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              !normalized.isEmpty else { return }

        items[index].isPinned = true
        items[index].favoriteFolder = normalized
        addFavoriteFolder(normalized)
        trim()
        persist()
    }

    func setTitle(_ item: ClipboardHistoryItem, title: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].title = normalized.isEmpty ? nil : normalized
        persist()
    }

    func addFavoriteFolder(_ folder: String) {
        let normalized = Self.normalizedFolderName(folder)
        guard !normalized.isEmpty,
              !favoriteFolders.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) else {
            return
        }

        favoriteFolders.append(normalized)
        favoriteFolders = Self.normalizedFolders(favoriteFolders)
        persistFolders()
    }

    func deleteFavoriteFolder(_ folder: String) {
        let normalized = Self.normalizedFolderName(folder)
        guard !normalized.isEmpty else { return }

        favoriteFolders.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        for index in items.indices where items[index].favoriteFolder?.caseInsensitiveCompare(normalized) == .orderedSame {
            items[index].isPinned = false
            items[index].favoriteFolder = nil
        }
        trim()
        persist()
        persistFolders()
    }

    func delete(_ item: ClipboardHistoryItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        persist()
    }

    private func trim() {
        let pinned = items.filter(\.isPinned)
        let unpinned = items.filter { !$0.isPinned }.prefix(maxUnpinnedCount)
        items = pinned + unpinned
    }

    private func persist() {
        do {
            try store.save(items, to: "clipboard.json")
        } catch {
            NSLog("NotchShelf clipboard persistence failed: \(error.localizedDescription)")
        }
    }

    private func persistFolders() {
        do {
            try store.save(favoriteFolders, to: "clipboard-folders.json")
        } catch {
            NSLog("NotchShelf favorite folder persistence failed: \(error.localizedDescription)")
        }
    }

    private static func normalizedFolderName(_ folder: String) -> String {
        folder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedFolders(_ folders: [String]) -> [String] {
        var seen: Set<String> = []
        return folders.compactMap { folder in
            let normalized = normalizedFolderName(folder)
            guard !normalized.isEmpty else { return nil }
            let key = normalized.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return normalized
        }
    }

    static func contentHash(for value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func looksLikeLink(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    @objc private func pasteboardTimerFired() {
        checkPasteboard()
    }
}
