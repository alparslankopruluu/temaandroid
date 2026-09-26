import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

enum AppTelemetry {
    static func log(_ event: Event) {
        Analytics.logEvent(event.rawValue, parameters: nil)
    }

    static func record(_ operation: Operation) {
        Crashlytics.crashlytics().record(
            error: NSError(domain: "ScreenMotion", code: operation.rawValue)
        )
    }

    enum Event: String {
        case appOpened = "app_opened"
        case onboardingViewed = "onboarding_viewed"
        case onboardingCompleted = "onboarding_completed"
        case proPaywallViewed = "pro_paywall_viewed"
        case proPurchaseCompleted = "pro_purchase_completed"
        case proPurchaseFailed = "pro_purchase_failed"
        case proRestoreCompleted = "pro_restore_completed"
        case proRestoreFailed = "pro_restore_failed"
        case editorViewed = "editor_viewed"
        case designSaved = "design_saved"
        case exportStarted = "export_started"
        case exportCompleted = "export_completed"
        case exportFailed = "export_failed"
    }

    enum Operation: Int {
        case anonymousIdentity = 1
        case purchaseLoad = 2
        case export = 3
        case debugVerification = 4
    }
}
