import Foundation

protocol CodexTaskStatusProviding {
    func loadTasks() async throws -> [CodexTask]
}

actor MockCodexTaskProvider: CodexTaskStatusProviding {
    private var tick = 0
    private let buildTaskID = UUID()
    private let reviewTaskID = UUID()
    private let blockedTaskID = UUID()

    func loadTasks() async throws -> [CodexTask] {
        tick += 1
        let now = Date()

        return [
            CodexTask(
                id: buildTaskID,
                title: "NotchShelf build",
                detail: tick < 3 ? "Implementing menu bar shell" : "Build shell ready",
                status: tick < 3 ? .running : .done,
                updatedAt: now
            ),
            CodexTask(
                id: reviewTaskID,
                title: "Clipboard review",
                detail: "Watching pasteboard behavior",
                status: .running,
                updatedAt: now
            ),
            CodexTask(
                id: blockedTaskID,
                title: "Codex provider",
                detail: tick < 5 ? "Waiting for stable local source" : "Needs provider decision",
                status: tick < 5 ? .running : .needsAttention,
                updatedAt: now
            )
        ]
    }
}
