import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

enum AppTelemetry {
    static func log(_ event: Event, _ parameters: [String: String]? = nil) {
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }

    /// Keeps the underlying domain and code so failures are diagnosable instead of a bare operation number.
    static func record(_ operation: Operation, underlying: Error? = nil) {
        var info: [String: Any] = [:]
        if let underlying {
            let nsError = underlying as NSError
            info["underlying_domain"] = nsError.domain
            info["underlying_code"] = nsError.code
            info[NSUnderlyingErrorKey] = nsError
        }
        Crashlytics.crashlytics().record(
            error: NSError(domain: "ScreenMotion", code: operation.rawValue, userInfo: info)
        )
    }

    enum Event: String {
        case appOpened = "app_opened"
        case onboardingViewed = "onboarding_viewed"
        case onboardingCompleted = "onboarding_completed"
        case onboardingStep = "onboarding_step"
        case onboardingInterests = "onboarding_interests"
        case proPaywallViewed = "pro_paywall_viewed"
        case proPaywallClosed = "pro_paywall_closed"
        case proPreviewChosen = "pro_preview_chosen"
        case proPlanSelected = "pro_plan_selected"
        case proPurchaseCompleted = "pro_purchase_completed"
        case proPurchaseCancelled = "pro_purchase_cancelled"
        case proPurchaseFailed = "pro_purchase_failed"
        case proRestoreCompleted = "pro_restore_completed"
        case proRestoreFailed = "pro_restore_failed"
        case editorViewed = "editor_viewed"
        case designSaved = "design_saved"
        case sceneOpened = "scene_opened"
        case completeLookOpened = "complete_look_opened"
        case exportStarted = "export_started"
        case exportCompleted = "export_completed"
        case exportFailed = "export_failed"
        case reviewRequested = "review_requested"
        case videoPickerViewed = "video_picker_viewed"
        case videoConverted = "video_converted"
        case nightstandOpened = "nightstand_opened"
        case pushPermission = "push_permission"
        case pushOpened = "push_opened"
        case chargingGuideViewed = "charging_guide_viewed"
        case tiltGuideViewed = "tilt_guide_viewed"
    }

    enum Operation: Int {
        case anonymousIdentity = 1
        case purchaseLoad = 2
        case export = 3
        case debugVerification = 4
        case purchase = 5
        case videoImport = 6
    }
}

/// Where a paywall was opened from, so conversion can be compared per entry point.
enum PaywallSource: String, Identifiable {
    case welcome, upgrade, push, lockedScene = "locked_scene", export, video, discover, settings
    var id: String { rawValue }
}
