import SwiftUI
import RevenueCat
import FirebaseCore

@main struct ScreenMotionApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var pushDelegate
    @State private var library = LibraryStore()
    @State private var content = ContentStore()
    @State private var purchases: PurchasesService
    init() {
        FirebaseApp.configure()
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
           apiKey.hasPrefix("appl_") {
            Purchases.configure(withAPIKey: apiKey)
        }
        _purchases = State(initialValue: PurchasesService())
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(library).environment(purchases).environment(content)
                .preferredColorScheme(.dark).tint(Design.accent)
        }
    }
}

struct RootView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PurchasesService.self) private var purchases
    @Environment(ContentStore.self) private var content
    @State private var selectedTab = 0
    @State private var linkedTheme: Theme?
    @State private var showLaunchPaywall = false
    @State private var showNightstand = false
    @State private var offerSource: PaywallSource?
    private var push: PushService { .shared }
    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView().tabItem { Label("tab.discover", systemImage: "square.grid.2x2") }.tag(0)
            LibraryView().tabItem { Label("tab.library", systemImage: "square.stack") }.tag(1)
            SettingsView().tabItem { Label("tab.settings", systemImage: "slider.horizontal.3") }.tag(2)
        }
        .fullScreenCover(isPresented: Binding(get: { !library.hasSeenWelcome }, set: { if !$0 { library.finishWelcome() } })) { WelcomeView() }
        .sheet(item: $linkedTheme) { theme in NavigationStack { EditorView(theme: theme) } }
        .sheet(isPresented: $showLaunchPaywall) { ProPaywallView(source: .upgrade) }
        .sheet(item: $offerSource) { ProPaywallView(source: $0) }
        .fullScreenCover(isPresented: $showNightstand) { NightstandView(theme: content.catalog.nightstandTheme(library.nightstandThemeID)) }
        .onOpenURL(perform: handle)
        .onChange(of: push.pendingLink, initial: true) { _, link in
            guard let link else { return }
            push.pendingLink = nil
            handle(link)
        }
        .onChange(of: purchases.isPro) { _, isPro in push.syncTopics(isPro: isPro) }
        .onReceive(NotificationCenter.default.publisher(for: .pushTokenReady)) { _ in push.syncTopics(isPro: purchases.isPro) }
        .task {
            AppTelemetry.log(.appOpened)
#if DEBUG
            if ProcessInfo.processInfo.environment["SCREENMOTION_VERIFY_CRASHLYTICS"] == "1" {
                AppTelemetry.record(.debugVerification)
            }
#endif
            await purchases.identifyAnonymousUser()
            async let purchaseLoad: Void = purchases.load()
            async let contentLoad: Void = content.refresh()
            _ = await (purchaseLoad, contentLoad)
            // New users meet the offer at the end of onboarding; people updating from an older version see it once here.
            guard library.hasSeenWelcome, !library.hasSeenLaunchPaywall, !purchases.isPro else { return }
            library.markLaunchPaywallSeen()
            showLaunchPaywall = true
        }
    }

    /// One router for widget, App Store event, notification and Shortcuts links.
    private func handle(_ url: URL) {
        guard url.scheme == "screenmotion", library.hasSeenWelcome else { return }
        switch url.host {
        case "theme": linkedTheme = content.catalog.theme(url.lastPathComponent)
        case "nightstand": showNightstand = true
        case "discover":
            // DiscoverView picks the request up through AppStorage.
            UserDefaults.standard.set(url.lastPathComponent, forKey: DiscoverView.filterRequestKey)
            selectedTab = 0
        case "offer": if !purchases.isPro { offerSource = .push }
        default: break
        }
    }
}
