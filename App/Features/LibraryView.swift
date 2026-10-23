import SwiftUI

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ContentStore.self) private var content
    @State private var selection = 0
    private var catalog: ThemeCatalog { content.catalog }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("library.subtitle").foregroundStyle(Design.muted)
                    Picker("tab.library", selection: $selection) { Text("library.designs").tag(0); Text("library.favorites").tag(1) }.pickerStyle(.segmented)
                    if selection == 0 {
                        if library.designs.isEmpty { empty }
                        ForEach(library.designs) { design in
                            if let theme = catalog.theme(design.themeID) {
                                NavigationLink { EditorView(theme: theme, configuration: design.configuration) } label: {
                                    HStack(spacing: 16) { ArtworkView(theme: theme).frame(width: 78, height: 100).clipped().clipShape(RoundedRectangle(cornerRadius: 18)); VStack(alignment: .leading, spacing: 8) { Text(theme.displayTitle).font(.headline); Text(design.savedAt, style: .date).font(.caption).foregroundStyle(Design.muted) }; Spacer(); Image(systemName: "arrow.up.right") }.padding(12).background(Design.surface, in: RoundedRectangle(cornerRadius: 22))
                                }.buttonStyle(.plain).contextMenu { Button("action.delete", role: .destructive) { library.delete(design.id) } }
                            }
                        }
                    } else {
                        let favorites = catalog.themes.filter { library.favorites.contains($0.id) }
                        if favorites.isEmpty { empty }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 22) { ForEach(favorites) { theme in NavigationLink { EditorView(theme: theme) } label: { ThemeCard(theme: theme) }.buttonStyle(.plain) } }
                    }
                }.padding(Design.padding)
            }.background(Design.background).navigationTitle("tab.library")
        }
    }
    private var empty: some View { ContentUnavailableView("library.empty", systemImage: "square.stack.3d.up", description: Text("library.emptyHint")).padding(.top, 60) }
}

struct SettingsView: View {
    @Environment(PurchasesService.self) private var purchases
    @Environment(ContentStore.self) private var content
    @Environment(LibraryStore.self) private var library
    @State private var showPro = false
    @State private var showNightstand = false
    @Environment(\.openURL) private var openURL
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showPro = true } label: { HStack { Image(systemName: "sparkles").foregroundStyle(Design.accent); VStack(alignment: .leading, spacing: 6) { Text(purchases.isPro ? "pro.active" : "pro.title").font(.headline); Text("pro.subtitle").font(.caption).foregroundStyle(Design.muted) }; Spacer(); Image(systemName: "chevron.right") }.padding(.vertical, 8) }
                    Button("purchase.restore") { Task { await purchases.restore() } }.disabled(purchases.busy)
                }
                Section("settings.help") {
                    NavigationLink("install.wallpaper", destination: InstallView(kind: .wallpaper))
                    NavigationLink("install.icons", destination: InstallView(kind: .icons))
                    NavigationLink("install.widgets", destination: InstallView(kind: .widgets))
                    if SpatialGuideView.isSupported { NavigationLink("spatial.navTitle", destination: SpatialGuideView()) }
                }
                Section("settings.tools") {
                    NavigationLink("discover.video", destination: VideoLiveView())
                    Button("discover.nightstand") { showNightstand = true }
                    notificationsRow
                }
                Section("settings.about") {
                    Text("platform.detail").font(.footnote)
                    Text("privacy.local").font(.footnote)
#if DEBUG
                    Text("settings.testBuild").font(.footnote).foregroundStyle(Design.muted)
#endif
                    if let url = URL(string: "https://screenmotion-legal.kprl884.workers.dev/support") { Link("legal.support", destination: url) }
                    if let url = URL(string: "https://screenmotion-legal.kprl884.workers.dev/privacy") { Link("legal.privacy", destination: url) }
                    if let url = URL(string: "https://screenmotion-legal.kprl884.workers.dev/terms") { Link("legal.terms", destination: url) }
                    LabeledContent("settings.version", value: version)
                }
                if let message = purchases.message { Text(LocalizedStringKey(message)).font(.footnote) }
            }.scrollContentBackground(.hidden).background(Design.background).navigationTitle("tab.settings").task { await PushService.shared.refreshAuthorization() }.sheet(isPresented: $showPro) { ProPaywallView(source: .settings) }
                .fullScreenCover(isPresented: $showNightstand) { NightstandView(theme: content.catalog.nightstandTheme(library.nightstandThemeID)) }
        }
    }
    /// Asks once; after a decision the row opens the system settings, the only place iOS lets users change it.
    @ViewBuilder private var notificationsRow: some View {
        let status = PushService.shared.authorization
        Button {
            if status == .notDetermined { Task { await PushService.shared.requestPermission(source: "settings") } }
            else if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
        } label: {
            LabeledContent("settings.notifications") {
                Text(status == .authorized || status == .provisional ? "settings.notifications.on" : "settings.notifications.off")
            }
        }
        .accessibilityIdentifier("settings.notifications")
    }
}
