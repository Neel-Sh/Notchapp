import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ShelfSectionView: View {
    @ObservedObject var store: ShelfStore
    @Binding var isDropTargeted: Bool
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        VStack(spacing: 8) {
            dropZone
                .padding(.horizontal, 12)

            if !selectedIDs.isEmpty {
                bulkToolbar
                    .padding(.horizontal, 12)
            }

            if store.items.isEmpty {
                EmptyStateView(systemImage: "tray.and.arrow.down", title: "Drop files to hold them for 2 days")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.items) { item in
                            ShelfRowView(
                                item: item,
                                isSelected: selectedIDs.contains(item.id),
                                onSelect: { toggleSelection(item.id) },
                                onOpen: { store.open(item) },
                                onReveal: { store.reveal(item) },
                                onCopyPath: { store.copyPath(item) },
                                onAirDrop: { store.airDrop(item) },
                                onPin: { store.togglePin(item) },
                                onRemove: { store.remove(item) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
                }
            }
        }
        .onChange(of: store.items) { _, items in
            selectedIDs = selectedIDs.filter { id in items.contains { $0.id == id } }
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isDropTargeted ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.08))
            .overlay(
                HStack(spacing: 8) {
                    Image(systemName: "plus.square.dashed")
                    Text("Drop files here")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(isDropTargeted ? Color.accentColor : Color.white.opacity(0.58))
            )
            .frame(height: 48)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
    }

    private var bulkToolbar: some View {
        HStack(spacing: 8) {
            Text("\(selectedIDs.count) selected")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            IconButton(systemImage: "square.and.arrow.up", help: "AirDrop selected", size: 13, frameSize: 28) {
                store.airDrop(ids: selectedIDs)
            }
            IconButton(systemImage: "doc.on.doc", help: "Copy selected paths", size: 13, frameSize: 28) {
                store.copyPaths(ids: selectedIDs)
            }
            IconButton(systemImage: "trash", help: "Remove selected", size: 13, frameSize: 28) {
                store.remove(ids: selectedIDs)
                selectedIDs.removeAll()
            }
            Button("Clear") {
                selectedIDs.removeAll()
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.58))
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = fileURL(from: item) else { return }
                Task { @MainActor in
                    do {
                        try store.addFile(from: url)
                    } catch {
                        NSLog("NotchShelf failed to add shelf file: \(error.localizedDescription)")
                    }
                }
            }
        }
        return accepted
    }

    private func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let string = item as? String {
            return URL(string: string)
        }
        return nil
    }
}

private struct ShelfRowView: View {
    let item: ShelfFileItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onCopyPath: () -> Void
    let onAirDrop: () -> Void
    let onPin: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 24, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSelected ? Color.accentColor : .white.opacity(0.44))

            Image(nsImage: NSWorkspace.shared.icon(forFile: item.storedPath))
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            HStack(spacing: 4) {
                IconButton(systemImage: "square.and.arrow.up", help: "AirDrop", size: 13, frameSize: 28, action: onAirDrop)
                IconButton(systemImage: "magnifyingglass", help: "Reveal in Finder", size: 13, frameSize: 28, action: onReveal)
                IconButton(systemImage: "doc.on.doc", help: "Copy path", size: 13, frameSize: 28, action: onCopyPath)
                IconButton(systemImage: item.isPinned ? "pin.fill" : "pin", help: item.isPinned ? "Unpin" : "Pin", size: 13, frameSize: 28, action: onPin)
                IconButton(systemImage: "trash", help: "Remove", size: 13, frameSize: 28, action: onRemove)
            }
            .fixedSize()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.38) : Color.white.opacity(0.07), lineWidth: 1)
        )
        .onTapGesture(count: 2, perform: onOpen)
        .onDrag {
            NSItemProvider(contentsOf: URL(fileURLWithPath: item.storedPath)) ?? NSItemProvider()
        }
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)
    }

    private var subtitle: String {
        var parts = [
            formattedSize,
            item.addedAt.formatted(date: .abbreviated, time: .shortened)
        ]
        if item.isPinned {
            parts.append("pinned")
        }
        return parts.joined(separator: " | ")
    }
}
