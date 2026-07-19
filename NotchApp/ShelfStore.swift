import AppKit
import Combine
import Foundation

@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfFileItem]

    private let store: LocalJSONStore
    private let retentionInterval: TimeInterval = 172_800

    init(store: LocalJSONStore) {
        self.store = store
        self.items = store.load([ShelfFileItem].self, from: "shelf.json", default: [])
        purgeExpired()
    }

    @discardableResult
    func addFile(from sourceURL: URL, date: Date = Date()) throws -> ShelfFileItem {
        try store.prepareDirectories()
        let destination = uniqueDestinationURL(for: sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let size = attributes[.size] as? NSNumber
        let item = ShelfFileItem(
            id: UUID(),
            originalName: sourceURL.lastPathComponent,
            storedPath: destination.path,
            sizeBytes: size?.int64Value ?? 0,
            addedAt: date,
            isPinned: false
        )

        items.insert(item, at: 0)
        purgeExpired(referenceDate: date)
        persist()
        return item
    }

    func uniqueDestinationURL(for filename: String) -> URL {
        let sanitized = filename.isEmpty ? "Dropped File" : filename
        let base = (sanitized as NSString).deletingPathExtension
        let ext = (sanitized as NSString).pathExtension
        var candidate = store.shelfDirectory.appendingPathComponent(sanitized)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            let nextName = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            candidate = store.shelfDirectory.appendingPathComponent(nextName)
            index += 1
        }

        return candidate
    }

    func togglePin(_ item: ShelfFileItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        items.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.addedAt > rhs.addedAt
        }
        persist()
    }

    func remove(_ item: ShelfFileItem) {
        items.removeAll { $0.id == item.id }
        try? FileManager.default.removeItem(atPath: item.storedPath)
        persist()
    }

    func remove(ids: Set<UUID>) {
        let removing = items.filter { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        for item in removing {
            try? FileManager.default.removeItem(atPath: item.storedPath)
        }
        persist()
    }

    func open(_ item: ShelfFileItem) {
        NSWorkspace.shared.open(URL(fileURLWithPath: item.storedPath))
    }

    func reveal(_ item: ShelfFileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.storedPath)])
    }

    func copyPath(_ item: ShelfFileItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.storedPath, forType: .string)
    }

    func copyPaths(ids: Set<UUID>) {
        let paths = items.filter { ids.contains($0.id) }.map(\.storedPath)
        guard !paths.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }

    func airDrop(_ item: ShelfFileItem) {
        airDrop(items: [item])
    }

    func airDrop(ids: Set<UUID>) {
        airDrop(items: items.filter { ids.contains($0.id) })
    }

    private func airDrop(items: [ShelfFileItem]) {
        let urls = items.map { URL(fileURLWithPath: $0.storedPath) }
        guard !urls.isEmpty,
              let service = NSSharingService(named: .sendViaAirDrop) else {
            return
        }

        service.perform(withItems: urls)
    }

    func purgeExpired(referenceDate: Date = Date()) {
        let expired = items.filter { !$0.isPinned && referenceDate.timeIntervalSince($0.addedAt) > retentionInterval }
        guard !expired.isEmpty else { return }

        items.removeAll { item in
            expired.contains { $0.id == item.id }
        }
        for item in expired {
            try? FileManager.default.removeItem(atPath: item.storedPath)
        }
        persist()
    }

    private func persist() {
        do {
            try store.save(items, to: "shelf.json")
        } catch {
            NSLog("NotchShelf shelf persistence failed: \(error.localizedDescription)")
        }
    }
}
