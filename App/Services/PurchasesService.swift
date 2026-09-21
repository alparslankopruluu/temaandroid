import Observation
import RevenueCat
#if DEBUG
import StoreKit
#endif

@MainActor @Observable final class PurchasesService {
    private(set) var isPro = false
    private(set) var offeringAvailable = false
    private(set) var busy = false
    var message: String?
    @ObservationIgnored private var updates: Task<Void, Never>?
#if DEBUG
    @ObservationIgnored private var localEntitlementOverride: Bool?
#endif
    static let entitlement = "pro"

    init() {
        updates = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard let self else { return }
                self.apply(customerInfo)
            }
        }
    }

    deinit { updates?.cancel() }

    func load() async {
        do {
            async let customerInfo = Purchases.shared.customerInfo()
            async let offerings = Purchases.shared.offerings()
            apply(try await customerInfo)
            offeringAvailable = try await offerings.current != nil
            message = offeringAvailable || isPro ? nil : "purchase.unavailable"
        } catch {
            offeringAvailable = false
            message = "purchase.unavailable"
        }
    }

    func restore() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            apply(try await Purchases.shared.restorePurchases())
            message = isPro ? "purchase.restored" : "purchase.none"
        } catch {
            message = "purchase.failed"
        }
    }

    func syncTransactions() async throws {
        apply(try await Purchases.shared.syncPurchases())
#if DEBUG
        var hasLocalEntitlement = false
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            if Self.testProductIDs.contains(transaction.productID), transaction.revocationDate == nil {
                hasLocalEntitlement = true
            }
        }
        localEntitlementOverride = hasLocalEntitlement
        isPro = hasLocalEntitlement
#endif
    }

    func apply(_ customerInfo: CustomerInfo) {
#if DEBUG
        if let localEntitlementOverride {
            isPro = localEntitlementOverride
            return
        }
#endif
        isPro = customerInfo.entitlements.active[Self.entitlement]?.isActive == true
    }

#if DEBUG
    private static let testProductIDs = ["com.screenmotion.pro.monthly", "com.screenmotion.pro.yearly"]
#endif
}

#if DEBUG
@MainActor @Observable final class RewardedAdService {
    private(set) var running = false
    func playTest() async throws {
        running = true; defer { running = false }
        try await Task.sleep(for: .seconds(3))
        try Task.checkCancellation()
    }
}
#endif
