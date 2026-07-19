import SwiftUI

struct TodaySectionView: View {
    @ObservedObject var calendar: CalendarStore
    @ObservedObject var keepAwake: KeepAwakeController

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            keepAwakeCard
                .padding(.horizontal, 12)

            calendarHeader
                .padding(.horizontal, 12)

            calendarContent
        }
        .onAppear {
            refreshMonth()
        }
    }

    private var keepAwakeCard: some View {
        HStack(spacing: 8) {
            Image(systemName: keepAwake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(keepAwake.isActive ? Color.accentColor : .white.opacity(0.58))
                .frame(width: 26, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(keepAwake.isActive ? "Keep Awake On" : "Keep Awake Off")
                    .font(.system(size: 12, weight: .medium))
                Text(keepAwakeSubtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.54))
            }

            Spacer()

            if keepAwake.isActive {
                Button("Off") {
                    keepAwake.stop()
                }
                .keyboardShortcut("k", modifiers: [.command])
            } else {
                Button("2h") {
                    keepAwake.start(duration: 7_200)
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Until Off") {
                    keepAwake.start()
                }
            }
        }
        .font(.system(size: 12, weight: .medium))
        .buttonStyle(.borderedProminent)
        .padding(8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var keepAwakeSubtitle: String {
        if let until = keepAwake.until {
            return "Until \(until.formatted(date: .omitted, time: .shortened))"
        }
        return keepAwake.isActive ? "Until turned off" : "Prevent display sleep while working"
    }

    private var calendarHeader: some View {
        HStack(spacing: 8) {
            IconButton(systemImage: "chevron.left", help: "Previous month", size: 12, frameSize: 26) {
                moveMonth(by: -1)
            }

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)

            IconButton(systemImage: "chevron.right", help: "Next month", size: 12, frameSize: 26) {
                moveMonth(by: 1)
            }

            IconButton(systemImage: "arrow.clockwise", help: "Refresh calendar", size: 13, frameSize: 28) {
                refreshMonth()
            }
            .keyboardShortcut("r", modifiers: [.command])
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch calendar.state {
        case .unknown:
            EmptyStateView(systemImage: "calendar", title: "Loading calendar")
        case .denied:
            EmptyStateView(systemImage: "calendar.badge.exclamationmark", title: "Allow Calendar access in System Settings")
        case .failed(let message):
            EmptyStateView(systemImage: "exclamationmark.triangle", title: message)
        case .allowed:
            VStack(spacing: 8) {
                monthGrid
                    .padding(.horizontal, 12)

                selectedDayEvents
            }
        }
    }

    private var monthGrid: some View {
        VStack(spacing: 5) {
            LazyVGrid(columns: gridColumns, spacing: 4) {
                ForEach(Calendar.current.veryShortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.44))
                        .frame(height: 14)
                }

                ForEach(calendarDays, id: \.self) { date in
                    DayCell(
                        date: date,
                        displayedMonth: displayedMonth,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        eventCount: eventCount(on: date)
                    ) {
                        selectedDate = date
                    }
                }
            }
        }
    }

    private var selectedDayEvents: some View {
        let events = events(on: selectedDate)
        return Group {
            if events.isEmpty {
                EmptyStateView(systemImage: "calendar", title: "No events for selected day")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(events) { event in
                            CalendarEventRow(event: event)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private var calendarDays: [Date] {
        let calendar = Calendar.current
        let month = calendar.monthInterval(containing: displayedMonth)
        let firstWeekday = calendar.component(.weekday, from: month.start)
        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: month.start) ?? month.start
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func eventCount(on date: Date) -> Int {
        events(on: date).count
    }

    private func events(on date: Date) -> [CalendarEventItem] {
        calendar.events.filter { event in
            Calendar.current.isDate(event.startDate, inSameDayAs: date)
                || (event.startDate < Calendar.current.endOfDay(for: date) && event.endDate > Calendar.current.startOfDay(for: date))
        }
    }

    private func moveMonth(by offset: Int) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
        selectedDate = Calendar.current.monthInterval(containing: displayedMonth).start
        refreshMonth()
    }

    private func refreshMonth() {
        let interval = Calendar.current.monthInterval(containing: displayedMonth)
        calendar.refresh(start: interval.start, end: interval.end)
    }
}

private struct DayCell: View {
    let date: Date
    let displayedMonth: Date
    let isSelected: Bool
    let eventCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .frame(height: 14)
                Circle()
                    .fill(eventCount > 0 ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isCurrentMonth ? .white : .white.opacity(0.28))
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month)
    }
}

private struct CalendarEventRow: View {
    let event: CalendarEventItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: event.isAllDay ? "calendar" : "clock")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var subtitle: String {
        if event.isAllDay {
            return "All day | \(event.calendarTitle)"
        }
        return "\(event.startDate.formatted(date: .omitted, time: .shortened))-\(event.endDate.formatted(date: .omitted, time: .shortened)) | \(event.calendarTitle)"
    }
}

private extension Calendar {
    func monthInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 2_678_400)
    }

    func endOfDay(for date: Date) -> Date {
        self.date(byAdding: .day, value: 1, to: startOfDay(for: date)) ?? date.addingTimeInterval(86_400)
    }
}
