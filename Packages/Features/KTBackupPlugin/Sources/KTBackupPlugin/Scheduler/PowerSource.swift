import Foundation
import IOKit.ps

enum PowerSource {
    static func isOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPMBatteryPowerKey
    }

    static func observeChanges(_ handler: @escaping () -> Void) -> CFRunLoopSource? {
        let box = Unmanaged.passRetained(PowerChangeBox(handler)).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<PowerChangeBox>.fromOpaque(context).takeUnretainedValue().handler()
        }, box)?.takeRetainedValue() else {
            Unmanaged<PowerChangeBox>.fromOpaque(box).release()
            return nil
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        return source
    }
}

final class PowerChangeBox {
    let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }
}
