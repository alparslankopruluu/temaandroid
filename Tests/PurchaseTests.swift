import XCTest
import StoreKitTest
@testable import ScreenMotion

final class PurchaseTests: XCTestCase {
    @MainActor func testLocalSubscriptionUnlocksAndRefundRevokesPro() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let purchases = PurchasesService()
        await purchases.load()
        XCTAssertTrue(purchases.offeringAvailable)
        try await purchases.syncTransactions()
        XCTAssertFalse(purchases.isPro)
        _ = try await session.buyProduct(identifier: "com.screenmotion.pro.monthly")
        for _ in 0..<10 where !purchases.isPro {
            try await Task.sleep(for: .milliseconds(200))
            try await purchases.syncTransactions()
        }
        XCTAssertTrue(purchases.isPro)
        try session.expireSubscription(productIdentifier: "com.screenmotion.pro.monthly")
        for _ in 0..<10 where purchases.isPro {
            try await Task.sleep(for: .milliseconds(200))
            try await purchases.syncTransactions()
        }
        XCTAssertFalse(purchases.isPro)
    }
}
