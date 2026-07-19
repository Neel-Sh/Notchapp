import SwiftUI

struct FocusSectionView: View {
    @ObservedObject var keepAwake: KeepAwakeController

    private enum KeepAwakeMode: String, CaseIterable, Identifiable {
        case off
        case twoHours
        case untilOff

        var id: String { rawValue }

        var title: String {
            switch self {
            case .off: "Off"
            case .twoHours: "2h"
            case .untilOff: "Until Off"
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            keepAwakeCard
                .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private var keepAwakeCard: some View {
        HStack(spacing: 10) {
            Image(systemName: keepAwake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(keepAwake.isActive ? Color.accentColor : .white.opacity(0.62))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(keepAwake.isActive ? "Keep Awake On" : "Keep Awake Off")
                    .font(.system(size: 13, weight: .semibold))
                keepAwakeStatus
            }

            Spacer()

            Picker("Keep Awake", selection: keepAwakeModeBinding) {
                ForEach(KeepAwakeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 118)
            .controlSize(.small)
            .keyboardShortcut("k", modifiers: [.command])
        }
        .font(.system(size: 12, weight: .medium))
        .padding(10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var keepAwakeStatus: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(statusText(at: context.date))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.56))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private var keepAwakeModeBinding: Binding<KeepAwakeMode> {
        Binding(
            get: {
                if !keepAwake.isActive {
                    return .off
                }
                return keepAwake.until == nil ? .untilOff : .twoHours
            },
            set: { mode in
                switch mode {
                case .off:
                    keepAwake.stop()
                case .twoHours:
                    keepAwake.start(duration: 7_200)
                case .untilOff:
                    keepAwake.start()
                }
            }
        )
    }

    private func statusText(at date: Date) -> String {
        guard keepAwake.isActive else {
            return "Prevent display sleep while working"
        }

        guard let until = keepAwake.until else {
            return "Until turned off"
        }

        let remaining = max(0, Int(until.timeIntervalSince(date).rounded(.down)))
        if remaining == 0 {
            return "Ending now"
        }

        let hours = remaining / 3_600
        let minutes = (remaining % 3_600) / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d:%02d remaining", hours, minutes, seconds)
    }
}
