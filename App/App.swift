import SwiftUI
import RevenueCat
import FirebaseCore

@main struct ScreenMotionApp: App {
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
    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView().tabItem { Label("tab.discover", systemImage: "square.grid.2x2") }.tag(0)
            LibraryView().tabItem { Label("tab.library", systemImage: "square.stack") }.tag(1)
            SettingsView().tabItem { Label("tab.settings", systemImage: "slider.horizontal.3") }.tag(2)
        }
        .fullScreenCover(isPresented: Binding(get: { !library.hasSeenWelcome }, set: { if !$0 { library.finishWelcome() } })) { WelcomeView() }
        .sheet(item: $linkedTheme) { theme in NavigationStack { EditorView(theme: theme) } }
        .onOpenURL { url in
            guard url.scheme == "screenmotion" else { return }
            if url.host == "theme" { linkedTheme = content.catalog.theme(url.lastPathComponent) }
        }
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
        }
    }
}
