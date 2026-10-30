import AppKit
import IOKit.ps

/// Read-only system signals. None of these need special permissions.
enum Sensors {
    static func secondsSinceAnyInput() -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    static func secondsSinceKeyPress() -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    }

    static func battery() -> (percent: Int, charging: Bool)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
                  let cap = desc[kIOPSCurrentCapacityKey] as? Int,
                  let maxCap = desc[kIOPSMaxCapacityKey] as? Int, maxCap > 0 else { continue }
            let onAC = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return (cap * 100 / maxCap, onAC)
        }
        return nil
    }
}
