import AppKit
import SwiftUI

struct NotesSectionView: View {
    @ObservedObject var store: QuickNotesStore
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Quick note", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .lineLimit(1...3)
                    .submitLabel(.done)
                    .onSubmit(addDraft)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                IconButton(systemImage: "plus", help: "Add note", size: 14, frameSize: 32) {
                    addDraft()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 12)

            if store.notes.isEmpty {
                EmptyStateView(systemImage: "note.text", title: "Capture small notes without switching apps")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.notes) { note in
                            NoteRowView(
                                note: note,
                                onCopy: { store.copy(note) },
                                onDelete: { store.delete(note) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func addDraft() {
        store.add(draft)
        draft = ""
    }
}

private struct NoteRowView: View {
    let note: QuickNoteItem
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.54))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            HStack(spacing: 4) {
                IconButton(systemImage: "doc.on.doc", help: "Copy note", size: 13, frameSize: 28, action: onCopy)
                IconButton(systemImage: "trash", help: "Delete note", size: 13, frameSize: 28, action: onDelete)
            }
            .fixedSize()
        }
        .padding(8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}
