#if canImport(Security)

import Foundation
import Security

/// When a ``KeychainItem`` value is readable, and whether it is included in backups — a
/// portable wrapper over the `kSecAttrAccessible…` classes.
///
/// The `…ThisDeviceOnly` variants keep the value off encrypted backups, so it never migrates to a
/// new device; the plain variants are backup-and-restore eligible. `afterFirstUnlock` is the
/// default for ``KeychainItem`` because it stays readable to background work after the user's first
/// unlock following a reboot — the right choice for a value your app reads on launch.
///
/// ```swift
/// let item = KeychainItem<String>(
///     service: "svc", account: "acct",
///     accessibility: .afterFirstUnlockThisDeviceOnly   // stays on this device only
/// )
/// print(item.accessibility == .afterFirstUnlockThisDeviceOnly)   // true
/// ```
public enum KeychainAccessibility: Sendable, Equatable {

    /// Readable only while the device is unlocked. Backup-eligible.
    case whenUnlocked

    /// Readable after the first unlock following a reboot, then until the next reboot.
    /// Backup-eligible. This is ``KeychainItem``'s default.
    case afterFirstUnlock

    /// Like ``whenUnlocked``, but never included in backups (stays on this device).
    case whenUnlockedThisDeviceOnly

    /// Like ``afterFirstUnlock``, but never included in backups (stays on this device).
    case afterFirstUnlockThisDeviceOnly

    /// Readable only while unlocked and only if a device passcode is set; removed if the passcode
    /// is cleared. Never included in backups.
    case whenPasscodeSetThisDeviceOnly

    /// The underlying `kSecAttrAccessible…` Core Foundation constant.
    var rawValue: CFString {
        switch self {
        case .whenUnlocked:
            return kSecAttrAccessibleWhenUnlocked
        case .afterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }
}

#endif
