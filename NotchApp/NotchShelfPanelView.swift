import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NotchContainerView: View {
    private enum Metrics {
        static let openTopClearance: CGFloat = 42
    }

    @ObservedObject var model: AppModel
    @ObservedObject var chrome: NotchChromeModel

    let clearAction: () -> Void
    let quitAction: () -> Void

    @State private var selectedSection: PanelSection = .clipboard
    @State private var isDropTargeted = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        let shellShape = NotchShellShape(
            topRadius: chrome.isOpen ? 14 : 6,
            bottomRadius: chrome.isOpen ? 20 : 14
        )

        ZStack(alignment: .top) {
            shellShape
            .fill(chrome.isOpen ? Color(red: 0.02, green: 0.02, blue: 0.025) : Color.black)
            .overlay {
                if chrome.isOpen {
                    NotchShellShape(topRadius: 14, bottomRadius: 20)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        .padding(0.5)
                }
            }
            .shadow(color: chrome.isOpen ? .black.opacity(0.42) : .clear, radius: 14, y: 6)

            if chrome.isOpen {
                openContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            } else {
                closedContent
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: chrome.isOpen)
        .frame(width: chrome.panelSize.width, height: chrome.panelSize.height)
        .clipShape(shellShape)
        .contentShape(shellShape)
        .compositingGroup()
        .onHover(perform: handleHover)
        .contextMenu {
            Button(chrome.isOpen ? "Close NotchShelf" : "Open NotchShelf") {
                chrome.toggle()
            }
            Button("Clear Clipboard Unpinned", action: clearAction)
            Divider()
            Button("Quit NotchShelf", action: quitAction)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            selectedSection = .shelf
            chrome.open()
            return handleDrop(providers)
        }
        .onChange(of: isDropTargeted) { _, targeted in
            guard targeted else { return }
            selectedSection = .shelf
            chrome.open()
        }
    }

    private var closedContent: some View {
        Color.clear
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            chrome.toggle()
        }
    }

    private var openContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                sectionButton(.clipboard)
                sectionButton(.shelf)
                sectionButton(.notes)
                sectionButton(.focus)
            }
            .padding(.horizontal, 14)
            .padding(.top, Metrics.openTopClearance)
            .padding(.bottom, 8)

            Group {
                switch selectedSection {
                case .clipboard:
                    ClipboardSectionView(store: model.clipboard)
                case .shelf:
                    ShelfSectionView(store: model.shelf, isDropTargeted: $isDropTargeted)
                case .notes:
                    NotesSectionView(store: model.notes)
                case .focus:
                    FocusSectionView(keepAwake: model.keepAwake)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .frame(width: chrome.panelSize.width, height: chrome.panelSize.height)
        .contentShape(Rectangle())
    }

    private func sectionButton(_ section: PanelSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 6) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(section.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(selectedSection == section ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
            .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(section.shortcut, modifiers: [.command])
        .help(section.title)
    }

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()
        chrome.isHovering = hovering

        if hovering {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    chrome.open()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(550))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if !isDropTargeted {
                        chrome.close()
                    }
                }
            }
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
                        try model.shelf.addFile(from: url)
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

struct NotchShellShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = max(0, min(topRadius, rect.height / 2))
        let bottom = max(0, min(bottomRadius, rect.height / 2))
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + top),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottom),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()

        return path
    }
}

enum PanelSection: String, CaseIterable, Identifiable {
    case clipboard
    case shelf
    case notes
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: "Clipboard"
        case .shelf: "Shelf"
        case .notes: "Notes"
        case .focus: "Focus"
        }
    }

    var systemImage: String {
        switch self {
        case .clipboard: "doc.on.clipboard"
        case .shelf: "tray.and.arrow.down"
        case .notes: "note.text"
        case .focus: "cup.and.saucer"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .clipboard: "1"
        case .shelf: "2"
        case .notes: "3"
        case .focus: "4"
        }
    }
}
