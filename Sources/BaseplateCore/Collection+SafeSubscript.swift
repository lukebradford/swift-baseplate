import Foundation

extension Collection {
    /// Returns the element at `index`, or `nil` when `index` is out of bounds.
    ///
    /// The regular subscript (`self[index]`) traps on an out-of-range index. This variant
    /// turns "is this index valid?" into an optional you can bind, which is the safe shape
    /// for indices that come from user input, decoded data, or arithmetic that might overflow
    /// the collection. It is `O(1)` for an integer-indexed `RandomAccessCollection` (e.g. `Array`)
    /// and `O(distance)` for a forward/bidirectional collection like `String` (it consults
    /// `indices.contains`, which walks such a collection).
    ///
    /// - Warning: Pass an index that belongs to *this* collection. Feeding in an index obtained from
    ///   a *different* collection instance — most importantly a `Set`/`Dictionary` index, which is
    ///   opaque and instance-specific — is undefined and can trap. This helper is intended for
    ///   integer- and `String`-indexed collections.
    ///
    /// This is the *only* collection helper Baseplate ships on purpose. Chunking, deduplicating,
    /// grouping, windowing, and similar transforms are owned by Apple's
    /// [`swift-algorithms`](https://github.com/apple/swift-algorithms) — add that package rather
    /// than reinventing them here (see `AGENTS.md`, invariant #1).
    ///
    /// ```swift
    /// let names = ["a", "b", "c"]
    /// print(names[safe: 1] ?? "—")   // "b"
    /// print(names[safe: 9] ?? "—")   // "—"  (no trap)
    /// ```
    ///
    /// - Parameter index: An index for this collection, whether or not it is within
    ///   `startIndex..<endIndex`.
    /// - Returns: The element at `index`, or `nil` if `index` is not a valid subscript position.
    public subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
