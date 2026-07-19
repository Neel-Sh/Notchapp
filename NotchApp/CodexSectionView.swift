import SwiftUI

struct CodexSectionView: View {
    let tasks: [CodexTask]
    let alerts: [TaskAlertSummary]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recent completions")
                            .font(.system(size: 12, weight: .semibold))
                        ForEach(alerts) { alert in
                            HStack(spacing: 8) {
                                Image(systemName: alert.status == .done ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(alert.status == .done ? .green : .orange)
                                Text(alert.title)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                ForEach(tasks) { task in
                    CodexTaskRow(task: task)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CodexTaskRow: View {
    let task: CodexTask

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20, height: 20)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(task.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(task.updatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var icon: String {
        switch task.status {
        case .running: "progress.indicator"
        case .done: "checkmark.circle.fill"
        case .needsAttention: "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch task.status {
        case .running: .blue
        case .done: .green
        case .needsAttention: .orange
        }
    }
}
