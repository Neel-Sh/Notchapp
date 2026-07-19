import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchChromeModel: ObservableObject {
    @Published var isOpen = false
    @Published var isHovering = false
    @Published var panelSize = CGSize(width: 184, height: 32)

    func open() {
        isOpen = true
    }

    func close() {
        isOpen = false
    }

    func toggle() {
        isOpen.toggle()
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
        static let preferredOpenSize = NSSize(width: 580, height: 430)
        static let minimumOpenSize = NSSize(width: 500, height: 372)
        static let horizontalScreenInset: CGFloat = 18
    }

    private let panel: NSPanel
    private let model: AppModel
    private let chrome = NotchChromeModel()
    private var cancellables: Set<AnyCancellable> = []

    var isOpen: Bool {
        chrome.isOpen
    }

    init(model: AppModel, clearAction: @escaping () -> Void, quitAction: @escaping () -> Void) {
        self.model = model
        chrome.panelSize = Metrics.fallbackClosedSize
        panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: Metrics.fallbackClosedSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
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
            quitAction: quitAction
        )
        panel.contentView = NSHostingView(rootView: rootView)

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
        resizeAndPosition(isOpen: chrome.isOpen)
        if chrome.isOpen {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func toggle() {
        chrome.toggle()
        show()
    }

    func open() {
        chrome.open()
        show()
    }

    func close() {
        chrome.close()
    }

    private func resizeAndPosition(isOpen: Bool) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = isOpen ? openSize(for: screen) : closedSize(for: screen)
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.maxY - size.height
        chrome.panelSize = size
        panel.setFrame(NSRect(x: x.rounded(.down), y: y.rounded(.down), width: size.width, height: size.height), display: true, animate: isOpen)
    }

    private func openSize(for screen: NSScreen) -> NSSize {
        let screenLimitedWidth = screen.frame.width - Metrics.horizontalScreenInset * 2
        let menuGapWidth = menuGapWidth(for: screen)
        let maxWidth = max(Metrics.minimumOpenSize.width, min(screenLimitedWidth, menuGapWidth, Metrics.preferredOpenSize.width))
        let maxHeight = min(Metrics.preferredOpenSize.height, max(Metrics.minimumOpenSize.height, screen.visibleFrame.height * 0.44))
        return NSSize(width: maxWidth.rounded(.down), height: maxHeight.rounded(.down))
    }

    private func menuGapWidth(for screen: NSScreen) -> CGFloat {
        guard let leftAreaWidth = screen.auxiliaryTopLeftArea?.width,
              let rightAreaWidth = screen.auxiliaryTopRightArea?.width else {
            return Metrics.preferredOpenSize.width
        }

        let notchWidth = screen.frame.width - leftAreaWidth - rightAreaWidth
        let sideAllowance = min(leftAreaWidth, rightAreaWidth) * 0.34
        return max(Metrics.minimumOpenSize.width, notchWidth + sideAllowance * 2)
    }

    private func closedSize(for screen: NSScreen) -> NSSize {
        var width = Metrics.fallbackClosedSize.width
        if let leftAreaWidth = screen.auxiliaryTopLeftArea?.width,
           let rightAreaWidth = screen.auxiliaryTopRightArea?.width {
            width = max(150, screen.frame.width - leftAreaWidth - rightAreaWidth + 4)
        }

        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let notchHeight = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : menuBarHeight
        let height = max(24, min(44, notchHeight))
        return NSSize(width: width, height: height)
    }

    @objc private func screenParametersChanged() {
        resizeAndPosition(isOpen: chrome.isOpen)
    }

    @objc private func activeSpaceChanged() {
        guard !chrome.isOpen else {
            resizeAndPosition(isOpen: true)
            return
        }
        panel.orderOut(nil)
        resizeAndPosition(isOpen: false)
        panel.orderFrontRegardless()
    }
}
