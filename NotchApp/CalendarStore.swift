import Combine
import EventKit
import Foundation

@MainActor
final class CalendarStore: ObservableObject {
    enum AuthorizationState: Equatable {
        case unknown
        case denied
        case allowed
        case failed(String)
    }

    @Published private(set) var state: AuthorizationState = .unknown
    @Published private(set) var events: [CalendarEventItem] = []

    private let eventStore = EKEventStore()

    func refresh() {
        let interval = Calendar.current.monthInterval(containing: Date())
        refresh(start: interval.start, end: interval.end)
    }

    func refresh(start: Date, end: Date) {
        Task {
            await loadEvents(start: start, end: end)
        }
    }

    func loadEvents(start: Date? = nil, end: Date? = nil) async {
        do {
            if try await requestAccessIfNeeded() {
                state = .allowed
                let interval = Calendar.current.monthInterval(containing: Date())
                events = fetchEvents(start: start ?? interval.start, end: end ?? interval.end)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func requestAccessIfNeeded() async throws -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return true
        case .notDetermined:
            if #available(macOS 14.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        case .denied, .restricted, .writeOnly:
            state = .denied
            return false
        @unknown default:
            state = .denied
            return false
        }
    }

    private func fetchEvents(start: Date, end: Date) -> [CalendarEventItem] {
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)

        return eventStore.events(matching: predicate)
            .filter { !$0.isDetached }
            .sorted { $0.startDate < $1.startDate }
            .map {
                CalendarEventItem(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title ?? "Untitled",
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    calendarTitle: $0.calendar.title,
                    isAllDay: $0.isAllDay
                )
            }
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}

private extension Calendar {
    func monthInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 2_678_400)
    }
}
