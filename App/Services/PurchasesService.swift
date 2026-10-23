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
    @ObservationIgnored private var identified = false

    init() {
        updates = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard let self else { return }
                self.apply(customerInfo)
            }
        }
    }

    deinit { updates?.cancel() }

    func identifyAnonymousUser() async {
        guard !identified else { return }
        do {
            let uid = try await AuthenticationService.shared.userID()
            let result = try await Purchases.shared.logIn(uid)
            identified = true
            apply(result.customerInfo)
        } catch {
            AppTelemetry.record(.anonymousIdentity)
            // Keep the existing anonymous RevenueCat purchase flow available during an auth outage.
        }
    }

    func load() async {
        do {
            async let customerInfo = Purchases.shared.customerInfo()
            async let offerings = Purchases.shared.offerings()
            apply(try await customerInfo)
            offeringAvailable = try await offerings.current != nil
            message = offeringAvailable || isPro ? nil : "purchase.unavailable"
        } catch {
            AppTelemetry.record(.purchaseLoad)
            offeringAvailable = false
            message = "purchase.unavailable"
        }
    }

    func restore() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            await identifyAnonymousUser()
            apply(try await Purchases.shared.restorePurchases())
            AppTelemetry.log(.proRestoreCompleted)
            message = isPro ? "purchase.restored" : "purchase.none"
        } catch {
            AppTelemetry.log(.proRestoreFailed)
            message = "purchase.failed"
        }
    }

    func purchase(_ package: Package, source: PaywallSource) async throws -> Bool {
        let context = ["source": source.rawValue, "plan": package.packageType == .annual ? "yearly" : package.packageType == .lifetime ? "lifetime" : "monthly"]
        await identifyAnonymousUser()
        message = nil
        let result: PurchaseResultData
        do {
            result = try await Purchases.shared.purchase(package: package)
        } catch ErrorCode.purchaseCancelledError {
            // The async API throws on cancel; closing the sheet is a choice, not a failure.
            AppTelemetry.log(.proPurchaseCancelled, context)
            return false
        } catch ErrorCode.paymentPendingError {
            // Ask to Buy or SCA: access arrives later through customerInfoStream.
            message = "purchase.pending"
            return false
        }
        guard !result.userCancelled else {
            AppTelemetry.log(.proPurchaseCancelled, context)
            return false
        }
        apply(result.customerInfo)
        if isPro { AppTelemetry.log(.proPurchaseCompleted, context) }
        return isPro
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
    private static let testProductIDs = ["com.screenmotion.pro.monthly", "com.screenmotion.pro.yearly", "com.screenmotion.pro.lifetime"]
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
