import FirebaseMessaging
import Observation
import UIKit
import UserNotifications

/// Firebase Cloud Messaging for new-scene and offer announcements. Campaigns are sent from the Firebase console
/// with a `link` data key (`screenmotion://theme/<id>`, `screenmotion://discover/<filter>`, `screenmotion://offer`);
/// targeting uses topics (`all`, `free` or `pro`, `lang_<code>`) or Analytics audiences.
@MainActor @Observable final class PushService {
    static let shared = PushService()
    /// A link from a tapped notification, consumed by RootView exactly like an opened URL.
    var pendingLink: URL?
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    @ObservationIgnored private var subscribedPro: Bool?

    private init() {}

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if authorization == .authorized || authorization == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Asked after a value moment (a second successful save or the Settings row), never at launch.
    func requestPermission(source: String) async {
        await refreshAuthorization()
        guard authorization == .notDetermined else { return }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        AppTelemetry.log(.pushPermission, ["granted": granted ? "1" : "0", "source": source])
        await refreshAuthorization()
    }

    /// Topics let a campaign reach everyone, only free users (offers) or only Pro users (new scenes), per language.
    func syncTopics(isPro: Bool) {
        guard Messaging.messaging().fcmToken != nil, subscribedPro != isPro else { return }
        subscribedPro = isPro
        let messaging = Messaging.messaging()
        messaging.subscribe(toTopic: "all")
        if let language = Locale.current.language.languageCode?.identifier { messaging.subscribe(toTopic: "lang_\(language)") }
        messaging.subscribe(toTopic: isPro ? "pro" : "free")
        messaging.unsubscribe(fromTopic: isPro ? "free" : "pro")
    }

    /// Only ScreenMotion links are followed, so a payload can never open an outside address.
    nonisolated static func link(from userInfo: [AnyHashable: Any]) -> URL? {
        guard let value = userInfo["link"] as? String, let url = URL(string: value), url.scheme == "screenmotion" else { return nil }
        return url
    }
}

/// Bridges UIKit notification callbacks into SwiftUI; Firebase swizzling maps the APNs token to an FCM token.
final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Task { await PushService.shared.refreshAuthorization() }
        return true
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard fcmToken != nil else { return }
        Task { @MainActor in NotificationCenter.default.post(name: .pushTokenReady, object: nil) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let url = PushService.link(from: response.notification.request.content.userInfo) else { return }
        await MainActor.run {
            AppTelemetry.log(.pushOpened, ["link": url.absoluteString])
            PushService.shared.pendingLink = url
        }
    }
}

extension Notification.Name {
    static let pushTokenReady = Notification.Name("ScreenMotionPushTokenReady")
}
