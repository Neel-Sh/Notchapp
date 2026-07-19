import Combine
import Foundation

@MainActor
final class AppModel: NSObject, ObservableObject {
    let clipboard: ClipboardHistoryStore
    let shelf: ShelfStore
    let notes: QuickNotesStore
    let calendar: CalendarStore
    let keepAwake: KeepAwakeController

    override convenience init() {
        self.init(store: LocalJSONStore())
    }

    init(store: LocalJSONStore) {
        self.clipboard = ClipboardHistoryStore(store: store)
        self.shelf = ShelfStore(store: store)
        self.notes = QuickNotesStore(store: store)
        self.calendar = CalendarStore()
        self.keepAwake = KeepAwakeController()
        super.init()

        do {
            try store.prepareDirectories()
        } catch {
            NSLog("NotchShelf directory setup failed: \(error.localizedDescription)")
        }
    }

    func start() {
        clipboard.startMonitoring()
        shelf.purgeExpired()
        calendar.refresh()
    }

    func stop() {
        clipboard.stopMonitoring()
        keepAwake.stop()
    }
}
