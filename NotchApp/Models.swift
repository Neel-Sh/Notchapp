import Foundation

enum ClipboardKind: String, Codable, Sendable {
    case text
    case link
}

struct ClipboardHistoryItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: ClipboardKind
    var value: String
    var createdAt: Date
    var lastCopiedAt: Date
    var isPinned: Bool
    var title: String?
    var favoriteFolder: String?
    var contentHash: String
}

struct ShelfFileItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var originalName: String
    var storedPath: String
    var sizeBytes: Int64
    var addedAt: Date
    var isPinned: Bool
}

struct QuickNoteItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var text: String
    var createdAt: Date
    var updatedAt: Date
}

struct CalendarEventItem: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var calendarTitle: String
    var isAllDay: Bool
}

enum CodexTaskStatus: String, Codable, Sendable {
    case running
    case done
    case needsAttention
}

struct CodexTask: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var detail: String
    var status: CodexTaskStatus
    var updatedAt: Date
}

struct TaskAlertSummary: Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var status: CodexTaskStatus
    var createdAt: Date
}
