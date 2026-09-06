import Foundation
import Testing

@testable import BaseplateStoreKit

@Suite struct TransactionFactTests {

    private let now = Date(timeIntervalSince1970: 1_000)

    @Test func non_expiring_purchase_is_active() {
        let fact = TransactionFact(productID: "p")
        #expect(fact.isActive(at: now))
        #expect(!fact.isExpired(at: now))
    }

    @Test func revoked_is_never_active() {
        let fact = TransactionFact(productID: "p", isRevoked: true)
        #expect(!fact.isActive(at: now))
    }

    @Test func revoked_is_not_expired_even_when_past_expiry() {
        let fact = TransactionFact(
            productID: "p", isRevoked: true, expirationDate: now.addingTimeInterval(-100))
        #expect(!fact.isExpired(at: now))
        #expect(!fact.isActive(at: now))
    }

    @Test func future_expiry_is_active() {
        let fact = TransactionFact(productID: "p", expirationDate: now.addingTimeInterval(60))
        #expect(fact.isActive(at: now))
        #expect(!fact.isExpired(at: now))
    }

    @Test func past_expiry_is_expired_not_active() {
        let fact = TransactionFact(productID: "p", expirationDate: now.addingTimeInterval(-1))
        #expect(!fact.isActive(at: now))
        #expect(fact.isExpired(at: now))
    }

    @Test func expiry_exactly_now_is_inclusive_and_not_active() {
        let fact = TransactionFact(productID: "p", expirationDate: now)
        #expect(!fact.isActive(at: now))
        #expect(fact.isExpired(at: now))
    }

    @Test func codable_round_trips() throws {
        let fact = TransactionFact(
            productID: "p", isRevoked: true, expirationDate: now)
        let data = try JSONEncoder().encode(fact)
        let decoded = try JSONDecoder().decode(TransactionFact.self, from: data)
        #expect(decoded == fact)
    }
}
