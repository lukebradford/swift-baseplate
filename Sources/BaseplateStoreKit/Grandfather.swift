import Foundation

/// A pure decision: does an install predate a cutoff version, and so deserve a feature for free?
///
/// The recurring indie situation: an app shipped a feature for free, then a later release puts it
/// behind Pro. Everyone who already had the app must keep it — otherwise the update silently takes
/// a feature away, which is the fastest way to earn one-star reviews. StoreKit 2's
/// `AppTransaction.originalAppVersion` (the app version originally purchased/downloaded) makes this
/// checkable on-device with no server: grant the feature to anyone whose original version is
/// *before* the first release that gated it.
///
/// This type is deliberately free of StoreKit so the decision is unit-testable from plain strings.
/// The caller reads `AppTransaction.shared` once (in the live layer), pulls `originalAppVersion`,
/// and passes it here. Versions are compared component-wise as integers, so `"1.9"` correctly sorts
/// before `"1.10"` (unlike a plain string compare), and differing component counts are handled
/// (`"2"` == `"2.0"` == `"2.0.0"`).
///
/// - Important: **`AppTransaction.originalAppVersion` is not the marketing version on iOS.** On iOS
///   it is the original **build number** (`CFBundleVersion`); only on macOS is it the marketing
///   version (`CFBundleShortVersionString`). Express `cutoff` in the *same* series you read from the
///   platform — a build number on iOS (e.g. `"412"`), a marketing version on macOS (e.g. `"1.4"`) —
///   or the comparison is meaningless. The examples below use marketing-version-shaped strings only
///   for readability.
///
/// ```swift
/// // "1.4" is the first release that gated the feature.
/// print(Grandfather.isGrandfathered(originalAppVersion: "1.3", boughtBefore: "1.4"))   // true
/// print(Grandfather.isGrandfathered(originalAppVersion: "1.4", boughtBefore: "1.4"))   // false
/// print(Grandfather.isGrandfathered(originalAppVersion: "1.10", boughtBefore: "1.9"))  // false
/// ```
public enum Grandfather {

    /// Whether an install's original app version is strictly older than the cutoff.
    ///
    /// The comparison is strict: an install whose original version *equals* the cutoff is **not**
    /// grandfathered, because the cutoff is the first version that gated the feature — its buyers
    /// arrived under the new rules. Malformed or empty version segments are treated as `0`, so
    /// unexpected input degrades to a defined (conservative) answer rather than a crash.
    ///
    /// ```swift
    /// // A subscriber whose first version was 8.11, cutoff 10.0 → grandfathered.
    /// print(Grandfather.isGrandfathered(originalAppVersion: "8.11", boughtBefore: "10.0"))  // true
    /// // Empty / unknown original version is treated as 0.0.0 → older than any real cutoff.
    /// print(Grandfather.isGrandfathered(originalAppVersion: "", boughtBefore: "1.0"))        // true
    /// ```
    ///
    /// - Parameters:
    ///   - originalAppVersion: The version the app was originally purchased/downloaded at
    ///     (`AppTransaction.originalAppVersion`), e.g. `"8.11"`.
    ///   - cutoff: The first release version that gated the feature. Installs *before* this are
    ///     grandfathered.
    /// - Returns: `true` when `originalAppVersion` sorts strictly before `cutoff`.
    public static func isGrandfathered(
        originalAppVersion: String, boughtBefore cutoff: String
    ) -> Bool {
        compare(originalAppVersion, cutoff) == .orderedAscending
    }

    /// Compares two dotted version strings component-wise as integers.
    ///
    /// Each string is split on `"."` and each segment parsed as an `Int` (a non-numeric or empty
    /// segment becomes `0`). Missing trailing components are treated as `0`, so `"2"`, `"2.0"`, and
    /// `"2.0.0"` compare equal. Internal helper, exposed to the test target so the ordering rules
    /// (numeric segments, differing lengths, malformed input) can be pinned directly.
    ///
    /// - Parameters:
    ///   - lhs: The left version string.
    ///   - rhs: The right version string.
    /// - Returns: `.orderedAscending` if `lhs < rhs`, `.orderedDescending` if `lhs > rhs`, else
    ///   `.orderedSame`.
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = segments(lhs)
        let right = segments(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    /// Splits a dotted version into integer segments, mapping any unparseable segment to `0`.
    private static func segments(_ version: String) -> [Int] {
        version.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
    }
}
