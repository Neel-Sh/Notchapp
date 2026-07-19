import Combine
import Foundation
import IOKit.pwr_mgt

@MainActor
final class KeepAwakeController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var until: Date?

    private var assertionID = IOPMAssertionID(0)
    private var timer: Timer?

    func toggle(duration: TimeInterval? = nil) {
        isActive ? stop() : start(duration: duration)
    }

    func start(duration: TimeInterval? = nil) {
        stop()

        let reason = "NotchShelf Keep Awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            NSLog("NotchShelf failed to create keep-awake assertion: \(result)")
            return
        }

        isActive = true
        if let duration {
            until = Date().addingTimeInterval(duration)
            timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.stop()
                }
            }
        } else {
            until = nil
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        until = nil

        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }
}
