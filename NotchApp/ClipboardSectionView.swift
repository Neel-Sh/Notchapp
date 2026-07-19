import AppKit
import SwiftUI

struct ClipboardSectionView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case recents = "Recents"
        case favorites = "Favorites"

        var id: String { rawValue }
    }

    @ObservedObject var store: ClipboardHistoryStore
    @State private var selectedMode: Mode = .recents
    @State private var selectedFolder: String?
    @State private var searchText = ""
    @State private var inspectedText: ClipboardHistoryItem?
    @State private var favoriteTarget: ClipboardHistoryItem?
    @State private var favoriteTitleDraft = ""
    @State private var favoriteFolderDraft: String?
    @State private var newFolderDraft = ""

    private var recents: [ClipboardHistoryItem] {
        store.items.filter { !$0.isPinned }
    }

    private var favorites: [ClipboardHistoryItem] {
        store.items.filter(\.isPinned)
    }

    private var baseItems: [ClipboardHistoryItem] {
        switch selectedMode {
        case .recents:
            return recents
        case .favorites:
            guard let selectedFolder else { return favorites }
            return favorites.filter { $0.favoriteFolder == selectedFolder }
        }
    }

    private var visibleItems: [ClipboardHistoryItem] {
        filteredItems(baseItems, query: searchText)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                header
                modeBar

                if selectedMode == .favorites {
                    folderBar
                }

                ClipboardSearchField(text: $searchText)
                    .padding(.horizontal, 12)

                ClipboardItemListView(
                    items: visibleItems,
                    emptySystemImage: selectedMode == .favorites ? "star" : "doc.on.clipboard",
                    emptyTitle: emptyTitle,
                    onCopy: store.copyBack,
                    onInspect: inspect,
                    onFavorite: beginFavoriteEdit,
                    onDelete: store.delete
                )
            }

            if let inspectedText {
                ClipboardTextInspector(item: inspectedText) {
                    self.inspectedText = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if let favoriteTarget {
                FavoriteEditorView(
                    item: favoriteTarget,
                    folders: store.favoriteFolders,
                    titleDraft: $favoriteTitleDraft,
                    selectedFolder: $favoriteFolderDraft,
                    newFolderDraft: $newFolderDraft,
                    onDeleteFolder: deleteFavoriteFolder,
                    onSave: saveFavorite,
                    onRemove: removeFavorite,
                    onClose: closeFavoriteEditor
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: inspectedText?.id)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: favoriteTarget?.id)
    }

    private var header: some View {
        HStack {
            Text(summary)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.58))
            Spacer()
            Button {
                store.clearUnpinned()
            } label: {
                Label("Clear Recents", systemImage: "trash")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .help("Clear recents only")
        }
        .padding(.horizontal, 12)
    }

    private var modeBar: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases) { mode in
                Button {
                    selectedMode = mode
                    searchText = ""
                } label: {
                    Label(mode.rawValue, systemImage: mode == .recents ? "clock" : "star")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(selectedMode == mode ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedMode == mode ? .white : .white.opacity(0.58))
            }
        }
        .padding(.horizontal, 12)
    }

    private var folderBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.favoriteFolders, id: \.self) { folder in
                    HStack(spacing: 3) {
                        Button {
                            selectedFolder = folder
                        } label: {
                        Text(folder)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .padding(.leading, 10)
                            .padding(.trailing, 5)
                            .frame(height: 25)
                        }
                        .buttonStyle(.plain)

                        Button {
                            deleteFavoriteFolder(folder)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .frame(width: 20, height: 25)
                        }
                        .buttonStyle(.plain)
                        .help("Delete folder")
                    }
                    .background(selectedFolder == folder ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .foregroundStyle(selectedFolder == folder ? .white : .white.opacity(0.58))
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var summary: String {
        if !searchText.isEmpty {
            return "\(visibleItems.count) matches"
        }
        switch selectedMode {
        case .recents:
            return "\(recents.count) recents"
        case .favorites:
            if let selectedFolder {
                return "\(visibleItems.count) in \(selectedFolder)"
            }
            return "\(favorites.count) favorites"
        }
    }

    private var emptyTitle: String {
        if !searchText.isEmpty {
            return "No matches"
        }
        switch selectedMode {
        case .recents:
            return "No recent clips"
        case .favorites:
            return favorites.isEmpty ? "No favorites yet" : "This folder is empty"
        }
    }

    private func beginFavoriteEdit(_ item: ClipboardHistoryItem) {
        favoriteTarget = item
        favoriteTitleDraft = item.title ?? ""
        favoriteFolderDraft = item.favoriteFolder
        newFolderDraft = ""
    }

    private func saveFavorite() {
        guard let favoriteTarget else { return }
        let customFolder = newFolderDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = customFolder.isEmpty ? (favoriteFolderDraft ?? "") : customFolder
        guard !folder.isEmpty else { return }
        store.setTitle(favoriteTarget, title: favoriteTitleDraft)
        store.setFavoriteFolder(favoriteTarget, folder: folder)
        selectedMode = .favorites
        selectedFolder = folder
        closeFavoriteEditor()
    }

    private func removeFavorite() {
        guard let favoriteTarget, favoriteTarget.isPinned else {
            closeFavoriteEditor()
            return
        }
        store.togglePin(favoriteTarget)
        closeFavoriteEditor()
    }

    private func closeFavoriteEditor() {
        favoriteTarget = nil
        favoriteTitleDraft = ""
        favoriteFolderDraft = nil
        newFolderDraft = ""
    }

    private func deleteFavoriteFolder(_ folder: String) {
        if selectedFolder == folder {
            selectedFolder = nil
        }
        if favoriteFolderDraft == folder {
            favoriteFolderDraft = nil
        }
        store.deleteFavoriteFolder(folder)
    }

    private func inspect(_ item: ClipboardHistoryItem) {
        switch item.kind {
        case .link:
            guard let url = URL(string: item.value) else { return }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            if let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                NSWorkspace.shared.open([url], withApplicationAt: safariURL, configuration: configuration)
            } else {
                NSWorkspace.shared.open(url)
            }
        case .text:
            inspectedText = item
        }
    }
}

private struct ClipboardItemListView: View {
    let items: [ClipboardHistoryItem]
    let emptySystemImage: String
    let emptyTitle: String
    let onCopy: (ClipboardHistoryItem) -> Void
    let onInspect: (ClipboardHistoryItem) -> Void
    let onFavorite: (ClipboardHistoryItem) -> Void
    let onDelete: (ClipboardHistoryItem) -> Void

    var body: some View {
        if items.isEmpty {
            EmptyStateView(systemImage: emptySystemImage, title: emptyTitle)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(items) { item in
                        ClipboardRowView(
                            item: item,
                            onCopy: { onCopy(item) },
                            onInspect: { onInspect(item) },
                            onFavorite: { onFavorite(item) },
                            onDelete: { onDelete(item) }
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
}

private struct ClipboardRowView: View {
    let item: ClipboardHistoryItem
    let onCopy: () -> Void
    let onInspect: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onInspect) {
                Image(systemName: item.kind == .link ? "link" : "text.alignleft")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(item.kind == .link ? .blue : .white.opacity(0.58))
            .help(item.kind == .link ? "Open in Safari" : "Inspect text")

            VStack(alignment: .leading, spacing: 4) {
                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(preview)
                    .font(.system(size: 12))
                    .lineLimit(item.title == nil ? 2 : 1)
                    .truncationMode(.middle)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    Text(item.lastCopiedAt.formatted(date: .omitted, time: .shortened))
                    if let folder = item.favoriteFolder, item.isPinned {
                        Text(folder)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.54))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            HStack(spacing: 4) {
                IconButton(systemImage: "doc.on.doc", help: "Copy back", size: 15, frameSize: 34, action: onCopy)
                IconButton(systemImage: item.isPinned ? "star.fill" : "star", help: "Favorite", size: 15, frameSize: 34, action: onFavorite)
                IconButton(systemImage: "trash", help: "Delete", size: 15, frameSize: 34, action: onDelete)
            }
            .fixedSize()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var preview: String {
        item.value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct FavoriteEditorView: View {
    let item: ClipboardHistoryItem
    let folders: [String]
    @Binding var titleDraft: String
    @Binding var selectedFolder: String?
    @Binding var newFolderDraft: String
    let onDeleteFolder: (String) -> Void
    let onSave: () -> Void
    let onRemove: () -> Void
    let onClose: () -> Void

    private var canSave: Bool {
        !newFolderDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedFolder != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.isPinned ? "Favorite" : "Add Favorite")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                IconButton(systemImage: "xmark", help: "Close", size: 13, frameSize: 28, action: onClose)
            }

            TextField("Identifier", text: $titleDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(folders, id: \.self) { folder in
                        HStack(spacing: 3) {
                            Button {
                                selectedFolder = folder
                                newFolderDraft = ""
                            } label: {
                                Text(folder)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .padding(.leading, 10)
                                    .padding(.trailing, 4)
                                    .frame(height: 26)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onDeleteFolder(folder)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .frame(width: 20, height: 26)
                            }
                            .buttonStyle(.plain)
                            .help("Delete folder")
                        }
                        .background(selectedFolder == folder && newFolderDraft.isEmpty ? Color.white.opacity(0.14) : Color.white.opacity(0.07))
                        .clipShape(Capsule())
                    }
                }
            }

            TextField("New folder", text: $newFolderDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                if item.isPinned {
                    Button("Remove") {
                        onRemove()
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(12)
    }
}

private struct ClipboardSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
            TextField("Search copied text", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.58))
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct ClipboardTextInspector: View {
    let item: ClipboardHistoryItem
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Text")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                IconButton(systemImage: "doc.on.doc", help: "Copy all", size: 15, frameSize: 34) {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(item.value, forType: .string)
                }
                IconButton(systemImage: "xmark", help: "Close", size: 13, frameSize: 28, action: onClose)
            }

            ScrollView {
                Text(item.value)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(Color(red: 0.015, green: 0.015, blue: 0.018))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .padding(12)
        .background(Color(red: 0.03, green: 0.03, blue: 0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(12)
    }
}

private func filteredItems(_ items: [ClipboardHistoryItem], query: String) -> [ClipboardHistoryItem] {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return items }

    return items.filter { item in
        item.value.localizedCaseInsensitiveContains(normalized)
            || (item.title?.localizedCaseInsensitiveContains(normalized) ?? false)
            || (item.favoriteFolder?.localizedCaseInsensitiveContains(normalized) ?? false)
    }
}
