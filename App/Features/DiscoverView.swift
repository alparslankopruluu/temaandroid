import SwiftUI

struct ArtworkView: View {
    let theme: Theme
    var body: some View {
        Group {
            if let artworkURL = theme.artworkURL {
                RemoteArtworkView(url: artworkURL)
            } else if theme.remoteScene != nil, theme.remoteAssetURLs["artwork"] != nil {
                RemoteThemeArtworkView(theme: theme)
            } else if theme.hasProgrammaticArtwork {
                PixelStaticArtwork(theme: theme)
            } else {
                Image(theme.artwork).resizable().scaledToFill()
            }
        }
        .accessibilityLabel(Text(theme.displayTitle))
    }
}

private struct RemoteThemeArtworkView: View {
    let theme: Theme
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Design.surface.overlay { ProgressView() } }
        }
        .task(id: "\(theme.id)-\(theme.remoteContentVersion ?? "")") {
            guard let source = theme.remoteAssetURLs["artwork"],
                  let version = theme.remoteContentVersion,
                  let file = await RemoteAssetCache.shared.thumbnailURL(
                      source: source, contentVersion: version, itemID: theme.id
                  ) else { return }
            image = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: file.path)?.preparingForDisplay()
            }.value
        }
    }
}

private struct RemoteArtworkView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Design.surface.overlay { ProgressView() } }
        }
        .task(id: url) {
            image = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: url.path)?.preparingForDisplay()
            }.value
        }
    }
}

private struct PixelStaticArtwork: View {
    let theme: Theme
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Design.surface.overlay { ProgressView() } }
        }
        .task(id: theme.id) {
            guard await SceneFrameRenderer.prepare(theme: theme) else { return }
            image = SceneFrameRenderer.image(theme: theme, configuration: .init(),
                                             size: CGSize(width: 600, height: 800), time: 1)
        }
    }
}

struct DiscoverView: View {
    @Environment(ContentStore.self) private var content
    @Environment(PurchasesService.self) private var purchases
    @State private var filter: DiscoverFilter = .all
    static let filterRequestKey = "discover-filter-request"
    @AppStorage(DiscoverView.filterRequestKey) private var filterRequest = ""
    @State private var query = ""
    @State private var showSearch = false
    @State private var showPro = false
    @State private var showVideo = false
    @State private var showNightstand = false
    @State private var editorTheme: Theme?
    private var catalog: ThemeCatalog { content.catalog }
    @Environment(LibraryStore.self) private var library
    /// Worlds picked in onboarding come first; the sort is stable so catalog order holds within each group.
    private var filtered: [Theme] {
        let matches = catalog.themes.filter { filter.matches($0) && (query.isEmpty || $0.displayTitle.localizedStandardContains(query)) }
        guard filter == .all else { return matches }
        var liked = library.interests.compactMap(DiscoverFilter.init(rawValue:))
        if ThemeCatalog.isHalloweenSeason(.now) { liked.insert(.halloween, at: 0) }
        guard !liked.isEmpty else { return matches }
        let isLiked: (Theme) -> Bool = { theme in liked.contains { $0.matches(theme) } }
        return matches.filter(isLiked) + matches.filter { !isLiked($0) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header.zIndex(1)
                    if showSearch { TextField("search.placeholder", text: $query).textFieldStyle(.roundedBorder).accessibilityIdentifier("themeSearch") }
                    if query.isEmpty, filter == .all {
                        if let theme = ThemeCatalog.featured(in: filtered) { hero(theme) }
                        shortcuts
                    }
                    filters
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 20) {
                        ForEach(filtered) { theme in
                            Button { open(theme) } label: { ThemeCard(theme: theme) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("theme.\(theme.id)")
                        }
                    }
                    if filtered.isEmpty { ContentUnavailableView.search(text: query) }
                    Text("discover.complete").font(.title2.bold()).padding(.top, 6)
                    ForEach(ThemeCollection.allCases) { item in
                        NavigationLink { PackageView(collection: item) } label: {
                            HStack(spacing: 16) {
                                Image(systemName: item.symbol).font(.title2).frame(width: 52, height: 52).background(Design.tint(item).opacity(0.14), in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(Design.tint(item))
                                VStack(alignment: .leading, spacing: 5) { Text(LocalizedStringKey(item.titleKey)).font(.headline); Text("package.subtitle").font(.caption).foregroundStyle(Design.muted) }
                                Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(Design.muted)
                            }.padding(16).background(Design.surface, in: RoundedRectangle(cornerRadius: 22))
                        }.buttonStyle(.plain)
                    }
                    Text("platform.short").font(.footnote).foregroundStyle(Design.muted).padding(.bottom, 20)
                }.padding(.horizontal, Design.padding).padding(.top, 10)
            }.background(Design.background).toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $editorTheme) { EditorView(theme: $0) }
                .sheet(isPresented: $showPro) { ProPaywallView(source: .discover) }
                .sheet(isPresented: $showVideo) { NavigationStack { VideoLiveView() } }
                .fullScreenCover(isPresented: $showNightstand) { NightstandView(theme: catalog.nightstandTheme(library.nightstandThemeID)) }
                .onChange(of: filterRequest, initial: true) { _, request in
                    guard let requested = DiscoverFilter(rawValue: request) else { return }
                    editorTheme = nil
                    filter = requested
                    filterRequest = ""
                }
        }
    }
    /// Every scene opens its free, interactive preview; the offer appears when the user tries to save a locked one.
    private func open(_ theme: Theme) {
        AppTelemetry.log(.sceneOpened, ["scene": theme.id, "locked": theme.isFree || purchases.isPro ? "0" : "1"])
        editorTheme = theme
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SCREENMOTION").font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(3).foregroundStyle(Design.accent)
                Text("discover.title").font(.largeTitle.bold()).lineLimit(2).minimumScaleFactor(0.75)
            }
            Spacer()
            Button { showSearch.toggle() } label: { Image(systemName: "magnifyingglass").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel(Text("search.title"))
            if !purchases.isPro {
                Button { showPro = true } label: { Text("PRO").font(.caption.bold()).padding(.horizontal, 13).frame(height: 44).foregroundStyle(.black).background(Design.accent, in: Capsule()) }
                    .accessibilityLabel(Text("pro.title")).accessibilityIdentifier("proButton")
            }
        }
    }
    private func hero(_ theme: Theme) -> some View {
        Button { open(theme) } label: {
            ZStack(alignment: .bottomLeading) {
                ScenePreview(theme: theme, configuration: SceneConfiguration(), isActive: editorTheme == nil)
                    .frame(height: 380).allowsHitTesting(false)
                LockScreenClock(compact: false).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(.top, 28)
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    Label("discover.featured", systemImage: "waveform.path").font(.caption.weight(.medium)).foregroundStyle(Design.accent)
                    HStack(alignment: .bottom) {
                        Text(theme.displayTitle).font(.system(size: 30, weight: .bold, design: .rounded)).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.title3).frame(width: 46, height: 46).background(.white.opacity(0.16), in: Circle())
                    }
                }.padding(22)
            }.frame(height: 380).clipShape(RoundedRectangle(cornerRadius: Design.radius))
        }.buttonStyle(.plain).accessibilityIdentifier("featuredTheme")
    }
    private var shortcuts: some View {
        HStack(spacing: 12) {
            shortcut("discover.video", detail: "discover.videoDetail", symbol: "livephoto", identifier: "openVideoLive") { showVideo = true }
            shortcut("discover.nightstand", detail: "discover.nightstandDetail", symbol: "clock", identifier: "openNightstand") { showNightstand = true }
        }
    }
    private func shortcut(_ title: String, detail: String, symbol: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).font(.title2).foregroundStyle(Design.accent)
                Text(LocalizedStringKey(title)).font(.headline).multilineTextAlignment(.leading)
                Text(LocalizedStringKey(detail)).font(.caption).foregroundStyle(Design.muted).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(16).background(Design.surface, in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
    }
    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DiscoverFilter.visible(in: catalog.themes)) { item in
                    Button { filter = item } label: {
                        Text(LocalizedStringKey(item.titleKey)).font(.subheadline.weight(.semibold)).padding(.horizontal, 18).frame(minHeight: 44)
                            .background(filter == item ? Design.accent : Design.surface, in: Capsule()).foregroundStyle(filter == item ? .black : .white)
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(filter == item ? .isSelected : []).accessibilityIdentifier("filter.\(item.rawValue)")
                }
            }
        }
    }
}

/// One row of pills replaces the separate style picker and collection filters.
enum DiscoverFilter: String, CaseIterable, Identifiable {
    case all, halloween, pixel, vehicles, ocean, cosmos, nature
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .all: "filter.all"
        case .halloween: "filter.halloween"
        case .pixel: "filter.pixel"
        default: "collection.\(rawValue)"
        }
    }
    func matches(_ theme: Theme) -> Bool {
        switch self {
        case .all: true
        case .halloween: theme.isHalloween
        case .pixel: theme.isPixel
        default: theme.collection.rawValue == rawValue
        }
    }
    /// Pills that have at least one scene, so a seasonal pill disappears with its content.
    static func visible(in themes: [Theme]) -> [DiscoverFilter] {
        allCases.filter { $0 == .all || themes.contains(where: $0.matches) }
    }
    /// Onboarding choices: every non-empty world except the catch-all.
    static func interests(in themes: [Theme]) -> [DiscoverFilter] { visible(in: themes).filter { $0 != .all } }
}

/// The date and time the way the iOS Lock Screen draws them, so every card reads as a wallpaper.
struct LockScreenClock: View {
    var compact = true
    /// Store screenshots use one fixed moment so every frame shows the same time.
    static func displayDate(_ date: Date) -> Date {
#if DEBUG
        if UserDefaults.standard.bool(forKey: "demo-clock") {
            return Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9, minute: 41)) ?? date
        }
#endif
        return date
    }
    /// Hours and minutes as the Lock Screen shows them; store captures use the locale's own default
    /// (9:41 in the US, 09:41 in Türkiye) rather than the capture machine's 24-hour preference.
    static func timeText(_ date: Date) -> String {
#if DEBUG
        if UserDefaults.standard.bool(forKey: "demo-clock") {
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.dateFormat = (DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: .current) ?? "H:mm")
                .replacingOccurrences(of: "a", with: "").trimmingCharacters(in: .whitespaces)
            return formatter.string(from: date)
        }
#endif
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }
    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = Self.displayDate(context.date)
            VStack(spacing: compact ? 0 : 2) {
                Text(date, format: .dateTime.weekday(.wide).month().day())
                    .font(compact ? .system(size: 9, weight: .semibold) : .subheadline.weight(.semibold))
                Text(Self.timeText(date))
                    .font(.system(size: compact ? 38 : 76, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            }
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        }
        .accessibilityHidden(true)
    }
}

struct ThemeCard: View {
    let theme: Theme
    @Environment(PurchasesService.self) private var purchases
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // A fixed 9:16 frame owns the size; filled artwork may never widen the grid column.
            Color.clear
                .aspectRatio(9 / 16, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay { ArtworkView(theme: theme) }
                .overlay(alignment: .top) { LockScreenClock().padding(.top, 14).padding(.horizontal, 8) }
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .contentShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08)))
            .overlay(alignment: .bottomTrailing) {
                if !theme.isFree && !purchases.isPro {
                    Image(systemName: "lock.fill").font(.caption).padding(9).background(.black.opacity(0.45), in: Circle()).padding(10)
                } else if theme.loopResource != nil {
                    Image(systemName: "play.fill").font(.caption).padding(9).background(.black.opacity(0.45), in: Circle()).padding(10)
                }
            }
            Text(theme.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
        }.contentShape(Rectangle())
    }
}
