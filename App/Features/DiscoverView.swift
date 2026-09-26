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
    @State private var collection: ThemeCollection?
    @State private var query = ""
    @State private var showSearch = false
    @State private var showPro = false
    @State private var appearance: ThemeAppearance?
    private var catalog: ThemeCatalog { content.catalog }
    private var filtered: [Theme] {
        catalog.themes.filter {
            (collection == nil || $0.collection == collection)
                && (appearance == nil || $0.appearance == appearance)
                && (query.isEmpty || $0.displayTitle.localizedStandardContains(query))
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header.zIndex(1)
                    if showSearch { TextField("search.placeholder", text: $query).textFieldStyle(.roundedBorder).accessibilityIdentifier("themeSearch") }
                    appearanceFilters
                    categories
                    if query.isEmpty, let theme = filtered.first { hero(theme) }
                    HStack { Text("discover.curated").font(.title2.bold()); Spacer(); Text(filtered.count, format: .number).foregroundStyle(Design.muted) }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 22) {
                        ForEach(filtered) { theme in
                            NavigationLink { EditorView(theme: theme) } label: { ThemeCard(theme: theme) }
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
                .sheet(isPresented: $showPro) { ProPaywallView() }
        }
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SCREENMOTION").font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(3).foregroundStyle(Design.accent)
                Text("discover.title").font(.largeTitle.bold()).lineLimit(2).minimumScaleFactor(0.75)
            }
            Spacer()
            Button { showSearch.toggle() } label: { Image(systemName: "magnifyingglass").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel(Text("search.title"))
            Button { showPro = true } label: { Text("PRO").font(.caption.bold()).padding(.horizontal, 13).frame(height: 44).background(Design.surface, in: Capsule()) }.accessibilityLabel(Text("pro.title"))
        }
    }
    private func hero(_ theme: Theme) -> some View {
        NavigationLink { EditorView(theme: theme) } label: {
            ZStack(alignment: .bottomLeading) {
                ArtworkView(theme: theme).frame(height: 350).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    Label("discover.featured", systemImage: "waveform.path").font(.caption.weight(.medium)).foregroundStyle(Design.accent)
                    Text("hero.title").font(.system(size: 34, weight: .bold, design: .rounded)).multilineTextAlignment(.leading)
                    HStack { Text("hero.subtitle").font(.subheadline).foregroundStyle(.white.opacity(0.75)); Spacer(); Image(systemName: "arrow.up.right").font(.title3).frame(width: 46, height: 46).background(.white.opacity(0.16), in: Circle()) }
                }.padding(24)
            }.frame(height: 350).clipShape(RoundedRectangle(cornerRadius: Design.radius))
        }.buttonStyle(.plain).accessibilityIdentifier("featuredTheme")
    }
    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryPill("filter.all", selected: collection == nil) { collection = nil }
                ForEach(ThemeCollection.allCases) { item in categoryPill(item.titleKey, selected: collection == item) { collection = item } }
            }
        }
    }
    private var appearanceFilters: some View {
        Picker("editor.style", selection: $appearance) {
            Text("filter.all").tag(ThemeAppearance?.none)
            Text("filter.realistic").tag(ThemeAppearance?.some(.realistic))
            Text("filter.pixel").tag(ThemeAppearance?.some(.pixel))
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("appearanceFilter")
    }
    private func categoryPill(_ key: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(LocalizedStringKey(key)).font(.subheadline.weight(.semibold)).padding(.horizontal, 18).frame(minHeight: 44).background(selected ? Design.accent : Design.surface, in: Capsule()).foregroundStyle(selected ? .black : .white) }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ThemeCard: View {
    let theme: Theme
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkView(theme: theme).frame(height: 226).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: theme.isFree ? "waveform.path" : "lock.fill").font(.caption).padding(10).background(.black.opacity(0.35), in: Circle()).padding(10)
                }
            Text(theme.displayTitle).font(.headline)
            HStack(spacing: 6) {
                Text(LocalizedStringKey(theme.collection.titleKey))
                Text("·")
                if theme.isPixel { Text("filter.pixel") }
                else { Text("filter.realistic") }
            }
            .font(.caption)
            .foregroundStyle(Design.muted)
        }.contentShape(Rectangle())
    }
}
