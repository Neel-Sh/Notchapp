import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NotchContainerView: View {
    private enum Metrics {
        static let minimumOpenTopClearance: CGFloat = 42
        static let contentTopSpacing: CGFloat = 12
        static let bezelShoulderRadius: CGFloat = 28
        static let bezelShoulderDepth: CGFloat = 30
        static let openContentSideInset: CGFloat = bezelShoulderRadius + 10
    }

    @ObservedObject var model: AppModel
    @ObservedObject var chrome: NotchChromeModel

    let clearAction: () -> Void
    let quitAction: () -> Void
    let shouldKeepOpen: () -> Bool

    @State private var selectedSection: PanelSection = .clipboard
    @State private var isDropTargeted = false
    @State private var openTask: Task<Void, Never>?
    @State private var dismissalTask: Task<Void, Never>?
    @State private var hoveredSection: PanelSection?
    @Namespace private var sectionSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shellShape = NotchBezelShellShape(
            notchWidth: chrome.notchWidth,
            notchHeight: chrome.notchHeight,
            bezelShoulderRadius: Metrics.bezelShoulderRadius,
            bezelShoulderDepth: Metrics.bezelShoulderDepth,
            bottomCornerRadius: chrome.usesExpandedAppearance ? 30 : 11
        )

        ZStack(alignment: .top) {
            shellSurface(shellShape)

            if chrome.showsOpenContent {
                openContent
                    .clipShape(shellShape, style: FillStyle(antialiased: true))
                    .transition(openContentTransition)
            } else if !chrome.usesExpandedAppearance {
                closedContent
                    .transition(.opacity)
            }
        }
        .animation(
            NotchMotion.contentAnimation(
                isVisible: chrome.showsOpenContent,
                reduceMotion: reduceMotion
            ),
            value: chrome.showsOpenContent
        )
        .animation(
            NotchMotion.animation(
                isOpen: chrome.usesExpandedAppearance,
                reduceMotion: reduceMotion
            ),
            value: chrome.usesExpandedAppearance
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(shellShape)
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
        .onChange(of: chrome.isOpen) { _, isOpen in
            if isOpen {
                monitorForDismissal()
            } else {
                dismissalTask?.cancel()
            }
        }
        .onDisappear {
            openTask?.cancel()
            dismissalTask?.cancel()
        }
        .onExitCommand {
            chrome.close()
        }
    }

    private var closedContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Capsule()
                .fill(Color.white.opacity(chrome.isHovering ? 0.34 : 0))
                .frame(width: 30, height: 2)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: reduceMotion ? 0 : 0.12), value: chrome.isHovering)
        .onTapGesture {
            chrome.toggle()
        }
        .accessibilityLabel("Open NotchShelf")
    }

    private var openContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                sectionButton(.clipboard)
                sectionButton(.shelf)
                sectionButton(.notes)
                sectionButton(.focus)
            }
            .padding(4)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 0.5)
            }
            .padding(.horizontal, 14)
            .padding(.top, openTopClearance)
            .padding(.bottom, 10)

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
            .id(selectedSection)
            .transition(.opacity)
            .animation(reduceMotion ? nil : .smooth(duration: 0.16), value: selectedSection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Metrics.openContentSideInset)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func sectionButton(_ section: PanelSection) -> some View {
        let isSelected = selectedSection == section
        let isHovered = hoveredSection == section

        return Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) {
                selectedSection = section
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.13))
                        .matchedGeometryEffect(id: "section-selection", in: sectionSelection)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.055))
                }

                HStack(spacing: 6) {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .symbolVariant(isSelected ? .fill : .none)
                    Text(section.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredSection = hovering ? section : (hoveredSection == section ? nil : hoveredSection)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isHovered)
        .keyboardShortcut(section.shortcut, modifiers: [.command])
        .help(section.title)
    }

    private func handleHover(_ hovering: Bool) {
        chrome.isHovering = hovering
        openTask?.cancel()

        guard hovering, !chrome.isOpen else { return }

        openTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                chrome.open()
            }
        }
    }

    private func monitorForDismissal() {
        dismissalTask?.cancel()
        dismissalTask = Task { @MainActor in
            let clock = ContinuousClock()
            var outsideSince: ContinuousClock.Instant?

            while chrome.isOpen, !Task.isCancelled {
                if isDropTargeted || shouldKeepOpen() {
                    outsideSince = nil
                } else if let outsideSince {
                    if outsideSince.duration(to: clock.now) >= .milliseconds(420) {
                        chrome.close()
                        return
                    }
                } else {
                    outsideSince = clock.now
                }

                try? await Task.sleep(for: .milliseconds(70))
            }
        }
    }

    private var openTopClearance: CGFloat {
        max(
            Metrics.minimumOpenTopClearance,
            Metrics.bezelShoulderDepth + Metrics.contentTopSpacing
        )
    }

    private func shellSurface(_ shape: NotchBezelShellShape) -> some View {
        ZStack {
            if !chrome.usesExpandedAppearance {
                Color.black
            } else if reduceTransparency {
                LinearGradient(
                    stops: [
                        .init(color: Color.black, location: 0),
                        .init(color: Color.black.opacity(0.96), location: 0.30),
                        .init(color: Color(red: 0.09, green: 0.09, blue: 0.105), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                liquidGlassLayer(shape)
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.98), location: 0),
                        .init(color: Color.black.opacity(0.92), location: 0.20),
                        .init(color: Color.black.opacity(0.70), location: 0.52),
                        .init(color: Color.black.opacity(0.30), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.56),
                        .init(color: Color.white.opacity(0.025), location: 0.78),
                        .init(color: Color.white.opacity(0.07), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipShape(shape, style: FillStyle(antialiased: true))
        .overlay {
            fallbackGlassEdge(shape)
        }
    }

    @ViewBuilder
    private func liquidGlassLayer(_ shape: NotchBezelShellShape) -> some View {
        if #available(macOS 26.0, *) {
            shape
                .fill(Color.clear)
                .glassEffect(.clear.tint(Color.black.opacity(0.10)), in: shape)
                .allowsHitTesting(false)
        } else {
            MacVisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func fallbackGlassEdge(_ shape: NotchBezelShellShape) -> some View {
        if chrome.usesExpandedAppearance {
            if #available(macOS 26.0, *) {
                EmptyView()
            } else {
                shape
                    .strokeBorder(Color.white.opacity(0.13), lineWidth: 1, antialiased: true)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: 0.30),
                                .init(color: Color.white.opacity(0.55), location: 0.68),
                                .init(color: .white, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private var openContentTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.992, anchor: .top))
                .combined(with: .offset(y: -4)),
            removal: .opacity
        )
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

struct NotchBezelShellShape: InsettableShape {
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var bezelShoulderRadius: CGFloat
    var bezelShoulderDepth: CGFloat
    var bottomCornerRadius: CGFloat
    private var insetAmount: CGFloat = 0

    init(
        notchWidth: CGFloat,
        notchHeight: CGFloat,
        bezelShoulderRadius: CGFloat,
        bezelShoulderDepth: CGFloat,
        bottomCornerRadius: CGFloat
    ) {
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.bezelShoulderRadius = bezelShoulderRadius
        self.bezelShoulderDepth = bezelShoulderDepth
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get {
            AnimatablePair(
                notchWidth,
                AnimatablePair(
                    notchHeight,
                    AnimatablePair(bezelShoulderRadius, bottomCornerRadius)
                )
            )
        }
        set {
            notchWidth = newValue.first
            notchHeight = newValue.second.first
            bezelShoulderRadius = newValue.second.second.first
            bottomCornerRadius = newValue.second.second.second
        }
    }

    func inset(by amount: CGFloat) -> NotchBezelShellShape {
        var insetShape = self
        insetShape.insetAmount += amount
        return insetShape
    }

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard bounds.width > 0, bounds.height > 0 else { return Path() }

        let effectiveNotchWidth = min(
            max(0, notchWidth - insetAmount * 2),
            bounds.width
        )
        let effectiveNotchHeight = min(
            max(0, notchHeight - insetAmount * 2),
            bounds.height
        )
        let availableBelowBezel = max(0, bounds.height - effectiveNotchHeight)
        guard availableBelowBezel > 1 else {
            let restingBounds = CGRect(
                x: bounds.midX - effectiveNotchWidth / 2,
                y: bounds.minY,
                width: effectiveNotchWidth,
                height: bounds.height
            )
            return closedPath(in: restingBounds)
        }

        let shoulderDepth = min(
            max(0, bezelShoulderDepth - insetAmount * 2),
            availableBelowBezel / 2
        )
        // The display bezel already provides the black band above the panel.
        // Begin the hook at the window edge instead of drawing that thickness again.
        let hookTop = bounds.minY
        let bodyTop = hookTop + shoulderDepth
        let bodyHeight = bounds.maxY - bodyTop

        let availableExpansion = max(0, (bounds.width - effectiveNotchWidth) / 2)
        let shoulderInset = min(
            max(0, bezelShoulderRadius - insetAmount),
            availableExpansion / 2
        )
        let bodyLeft = bounds.minX + shoulderInset
        let bodyRight = bounds.maxX - shoulderInset
        let bodyWidth = bodyRight - bodyLeft
        // The hook leaves the underside of the bezel horizontally and settles
        // into the panel vertically. This is a quarter-ellipse approximation,
        // not the inverted vertical-first curve that makes the shoulder bulky.
        let hookControl: CGFloat = 0.58
        let horizontalControl = shoulderInset * hookControl
        let verticalControl = shoulderDepth * hookControl
        let bottom = min(
            max(0, bottomCornerRadius - insetAmount),
            bodyWidth / 2,
            bodyHeight / 2
        )
        let bodyRect = CGRect(x: bodyLeft, y: bodyTop, width: bodyWidth, height: bodyHeight)
        let bodyShape = UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: bottom,
                bottomTrailing: bottom,
                topTrailing: 0
            ),
            style: .continuous
        )
        var path = Path()

        path.addPath(bodyShape.path(in: bodyRect))
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addCurve(
            to: CGPoint(x: bodyRight, y: bodyTop),
            control1: CGPoint(x: bounds.maxX - horizontalControl, y: hookTop),
            control2: CGPoint(x: bodyRight, y: bodyTop - verticalControl)
        )
        path.addLine(to: CGPoint(x: bodyLeft, y: bodyTop))
        path.addCurve(
            to: CGPoint(x: bounds.minX, y: hookTop),
            control1: CGPoint(x: bodyLeft, y: bodyTop - verticalControl),
            control2: CGPoint(x: bounds.minX + horizontalControl, y: hookTop)
        )
        path.closeSubpath()

        return path
    }

    private func closedPath(in rect: CGRect) -> Path {
        let top: CGFloat = min(2, rect.height / 2)
        let bottom = min(
            max(0, bottomCornerRadius - insetAmount),
            rect.width / 2,
            rect.height / 2
        )
        let shape = UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: top,
                bottomLeading: bottom,
                bottomTrailing: bottom,
                topTrailing: top
            ),
            style: .continuous
        )
        return shape.path(in: rect)
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
