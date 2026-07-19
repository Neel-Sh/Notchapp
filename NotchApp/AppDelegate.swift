import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var notchPanelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.processInfo.isRunningUnitTests else { return }
        NSApp.setActivationPolicy(.accessory)
        setupNotchPanel()
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func setupNotchPanel() {
        notchPanelController = NotchPanelController(
            model: model,
            clearAction: { [weak self] in
                self?.clearClipboardUnpinned()
            },
            quitAction: { [weak self] in
                self?.quit()
            }
        )
        notchPanelController?.show()
    }

    @objc private func clearClipboardUnpinned() {
        model.clipboard.clearUnpinned()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private extension ProcessInfo {
    var isRunningUnitTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
