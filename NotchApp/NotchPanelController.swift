import AppKit
import Combine
import SwiftUI

enum NotchMotion {
    static func animation(isOpen: Bool, reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .easeOut(duration: 0.12)
        }

        return isOpen
            ? .smooth(duration: 0.34)
            : .smooth(duration: 0.28)
    }

    static func contentAnimation(isVisible: Bool, reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .easeOut(duration: 0.08)
        }

        return isVisible
            ? .smooth(duration: 0.20)
            : .easeOut(duration: 0.12)
    }
}

@MainActor
final class NotchChromeModel: ObservableObject {
    @Published var isOpen = false
    @Published var isHovering = false
    @Published var notchWidth: CGFloat = 184
    @Published var notchHeight: CGFloat = 32
    @Published private(set) var showsOpenContent = false
    @Published private(set) var usesExpandedAppearance = false
    @Published private(set) var isTransitioning = false

    func open() {
        guard !isOpen else { return }

        usesExpandedAppearance = true
        showsOpenContent = true
        isTransitioning = true
        isOpen = true
    }

    func close() {
        guard isOpen else { return }

        showsOpenContent = false
        isTransitioning = true
        isOpen = false
    }

    func toggle() {
        if isOpen {
            close()
        } else {
            open()
        }
    }

    func completeFrameTransition(towardOpen: Bool) {
        guard isOpen == towardOpen else { return }

        isTransitioning = false
        if !towardOpen {
            usesExpandedAppearance = false
        }
    }
}

@MainActor
private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class NotchPanelController {
    private enum Metrics {
        static let fallbackClosedSize = NSSize(width: 184, height: 32)
        static let preferredOpenSize = NSSize(width: 560, height: 408)
        static let minimumOpenSize = NSSize(width: 480, height: 360)
        static let horizontalScreenInset: CGFloat = 24
    }

    private let panel: NSPanel
    private let model: AppModel
    private let chrome = NotchChromeModel()
    private var cancellables: Set<AnyCancellable> = []
    private var frameTransitionID = 0

    var isOpen: Bool {
        chrome.isOpen
    }

    init(model: AppModel, clearAction: @escaping () -> Void, quitAction: @escaping () -> Void) {
        self.model = model
        let notchPanel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: Metrics.fallbackClosedSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel = notchPanel
        panel.isFloatingPanel = true
        panel.level = .mainMenu + 3
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.sharingType = .none
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.hasShadow = false
        panel.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false

        let rootView = NotchContainerView(
            model: model,
            chrome: chrome,
            clearAction: clearAction,
            quitAction: quitAction,
            shouldKeepOpen: { [weak notchPanel] in
                guard let notchPanel else { return false }
                return NotchPointerInteraction.shouldKeepOpen(
                    panelFrame: notchPanel.frame,
                    isKeyWindow: notchPanel.isKeyWindow,
                    mouseLocation: NSEvent.mouseLocation
                )
            }
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layerContentsRedrawPolicy = .duringViewResize
        panel.contentView = hostingView

        chrome.$isOpen
            .removeDuplicates()
            .sink { [weak self] isOpen in
                self?.resizeAndPosition(isOpen: isOpen)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    func show() {
        resizeAndPosition(isOpen: chrome.isOpen, animated: false)
        if chrome.isOpen {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func toggle() {
        chrome.toggle()
        panel.orderFrontRegardless()
    }

    func open() {
        chrome.open()
        panel.orderFrontRegardless()
    }

    func close() {
        chrome.close()
    }

    private func resizeAndPosition(isOpen: Bool, animated: Bool = true) {
        frameTransitionID &+= 1
        let transitionID = frameTransitionID

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let restingSize = closedSize(for: screen)
        let size = isOpen ? openSize(for: screen) : restingSize
        let anchorX = cameraHousingFrame(for: screen)?.midX ?? screen.frame.midX
        let x = anchorX - size.width / 2
        let y = screen.frame.maxY - size.height
        let proposedFrame = NSRect(
            x: x,
            y: y,
            width: size.width,
            height: size.height
        )
        let frame = screen.backingAlignedRect(proposedFrame, options: .alignAllEdgesNearest)

        chrome.notchWidth = restingSize.width
        chrome.notchHeight = restingSize.height

        guard animated, panel.isVisible, panel.frame != frame else {
            panel.setFrame(frame, display: true)
            chrome.completeFrameTransition(towardOpen: isOpen)
            return
        }

        let animation = NotchMotion.animation(
            isOpen: isOpen,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        NSAnimationContext.animate(animation) {
            panel.animator().setFrame(frame, display: true)
        } completion: { [weak self] in
            guard let self, self.frameTransitionID == transitionID else { return }
            self.chrome.completeFrameTransition(towardOpen: isOpen)
        }
    }

    private func openSize(for screen: NSScreen) -> NSSize {
        let screenLimitedWidth = screen.frame.width - Metrics.horizontalScreenInset * 2
        let maxWidth = min(
            Metrics.preferredOpenSize.width,
            max(Metrics.minimumOpenSize.width, screenLimitedWidth)
        )
        let maxHeight = min(
            Metrics.preferredOpenSize.height,
            max(Metrics.minimumOpenSize.height, screen.visibleFrame.height * 0.48)
        )
        return NSSize(width: maxWidth.rounded(.down), height: maxHeight.rounded(.down))
    }

    private func closedSize(for screen: NSScreen) -> NSSize {
        if let housingFrame = cameraHousingFrame(for: screen) {
            return housingFrame.size
        }

        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let height = max(24, min(44, menuBarHeight))
        return NSSize(width: Metrics.fallbackClosedSize.width, height: height)
    }

    private func cameraHousingFrame(for screen: NSScreen) -> NSRect? {
        NotchScreenGeometry.cameraHousingFrame(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            leftArea: screen.auxiliaryTopLeftArea,
            rightArea: screen.auxiliaryTopRightArea
        )
    }

    @objc private func screenParametersChanged() {
        resizeAndPosition(isOpen: chrome.isOpen, animated: false)
    }

    @objc private func activeSpaceChanged() {
        guard !chrome.isOpen else {
            resizeAndPosition(isOpen: true, animated: false)
            return
        }
        panel.orderOut(nil)
        resizeAndPosition(isOpen: false, animated: false)
        panel.orderFrontRegardless()
    }
}

enum NotchPointerInteraction {
    static func shouldKeepOpen(
        panelFrame: NSRect,
        isKeyWindow: Bool,
        mouseLocation: NSPoint,
        edgeTolerance: CGFloat = 6
    ) -> Bool {
        isKeyWindow || panelFrame.insetBy(dx: -edgeTolerance, dy: -edgeTolerance).contains(mouseLocation)
    }
}

enum NotchScreenGeometry {
    static func cameraHousingFrame(
        screenFrame: NSRect,
        safeAreaTop: CGFloat,
        leftArea: NSRect?,
        rightArea: NSRect?
    ) -> NSRect? {
        guard safeAreaTop > 0,
              let leftArea,
              let rightArea,
              rightArea.minX > leftArea.maxX else {
            return nil
        }

        return NSRect(
            x: leftArea.maxX,
            y: screenFrame.maxY - safeAreaTop,
            width: rightArea.minX - leftArea.maxX,
            height: safeAreaTop
        )
    }
}
