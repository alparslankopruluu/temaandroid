import SwiftUI

/// Three short value pages, an interest pick, then one dismissible offer. Skip is always one tap away.
struct WelcomeView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ContentStore.self) private var content
    @Environment(PurchasesService.self) private var purchases
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 44.0
    @State private var page = 0
    @State private var picked: Set<DiscoverFilter> = []
    @State private var showOffer = false
    private static let pageCount = 3

    private var themes: [Theme] { content.catalog.themes }
    private var heroTheme: Theme? { ThemeCatalog.featured(in: themes) }
    /// A cinematic loop the user cannot save yet, shown on the video page as the "after" picture.
    private var videoTheme: Theme? { themes.first { $0.loopResource != nil && $0.id != heroTheme?.id } ?? heroTheme }
    /// The offer opens on a Pro scene from the worlds the user just picked, so the price sits next to what it unlocks.
    private var offerTheme: Theme? {
        guard !picked.isEmpty else { return ThemeCatalog.offer(in: themes) }
        let pool = themes.filter { theme in picked.contains { $0.matches(theme) } }
        return pool.first { !$0.isFree && $0.loopResource != nil } ?? pool.first { !$0.isFree } ?? ThemeCatalog.offer(in: themes)
    }

    var body: some View {
        Group {
            if showOffer {
                ProPaywallView(source: .welcome, theme: offerTheme)
            } else {
                pages
            }
        }
        .background(Design.background)
        .onAppear { AppTelemetry.log(.onboardingViewed) }
        .onChange(of: page) { _, value in AppTelemetry.log(.onboardingStep, ["step": String(value)]) }
    }

    private var pages: some View {
        ZStack(alignment: .top) {
            TabView(selection: $page) {
                heroPage.tag(0)
                videoPage.tag(1)
                interestPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            HStack {
                Text("SCREENMOTION").font(.system(.caption, design: .monospaced).weight(.semibold)).tracking(4)
                Spacer()
                Button("action.skip") { finish() }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("startExploring")
            }
            .padding(.horizontal, Design.padding).padding(.top, 8)
        }
    }

    private var heroPage: some View {
        scenePage(theme: heroTheme, interactive: true, lockScreen: false) {
            Label("welcome.interact", systemImage: "hand.draw").font(.subheadline)
                .padding(.horizontal, 15).padding(.vertical, 10).background(.ultraThinMaterial, in: Capsule())
            Text("welcome.title").font(.system(size: titleSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
            Text("welcome.subtitle").font(.body).foregroundStyle(.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
            next("welcome.start")
        }
    }

    private var videoPage: some View {
        scenePage(theme: videoTheme, interactive: false, lockScreen: true) {
            Label("onboarding.video.badge", systemImage: "livephoto").font(.subheadline.weight(.semibold)).foregroundStyle(.black)
                .padding(.horizontal, 15).padding(.vertical, 10).background(Design.accent, in: Capsule())
            Text("onboarding.video.title").font(.system(size: titleSize * 0.85, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
            Text("onboarding.video.detail").font(.body).foregroundStyle(.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
            next("onboarding.next")
        }
    }

    private var interestPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 70)
            Text("onboarding.interests.title").font(.system(size: titleSize * 0.75, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text("onboarding.interests.detail").foregroundStyle(Design.muted)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(DiscoverFilter.interests(in: themes)) { item in interestCard(item) }
            }
            Spacer()
            PrimaryButton(title: picked.isEmpty ? "onboarding.next" : "onboarding.interests.done") { finishPages() }
            Text("welcome.note").font(.caption).foregroundStyle(Design.muted).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Design.padding).padding(.bottom, 24)
    }

    private func interestCard(_ item: DiscoverFilter) -> some View {
        let selected = picked.contains(item)
        let sample = themes.first(where: item.matches)
        return Button {
            if selected { picked.remove(item) } else { picked.insert(item) }
        } label: {
            ZStack(alignment: .bottomLeading) {
                Color.clear.frame(height: 108)
                    .overlay { if let sample { ArtworkView(theme: sample).allowsHitTesting(false) } }
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                Text(LocalizedStringKey(item.titleKey)).font(.subheadline.weight(.semibold)).padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Design.accent : .white.opacity(0.1), lineWidth: selected ? 3 : 1))
            .overlay(alignment: .topTrailing) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3)
                    .foregroundStyle(selected ? Design.accent : .white.opacity(0.8)).padding(8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("interest.\(item.rawValue)")
    }

    /// A full-bleed living scene under the page copy; only the first page reacts to touch.
    private func scenePage<Content: View>(theme: Theme?, interactive: Bool, lockScreen: Bool, @ViewBuilder content: () -> Content) -> some View {
        let copy = content()
        return GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if let theme {
                    ScenePreview(theme: theme, configuration: SceneConfiguration())
                        .allowsHitTesting(interactive)
                        .ignoresSafeArea()
                }
                if lockScreen {
                    // The clock makes the loop read as a Lock Screen, which is where the user's video ends up.
                    LockScreenClock(compact: false).frame(maxHeight: .infinity, alignment: .top).padding(.top, 110)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.25), Design.background], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) { copy }
                    .padding(Design.padding).padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func next(_ title: String) -> some View {
        PrimaryButton(title: title) { withAnimation { page = min(page + 1, Self.pageCount - 1) } }
    }

    private func finishPages() {
        library.setInterests(DiscoverFilter.allCases.filter(picked.contains).map(\.rawValue))
        AppTelemetry.log(.onboardingInterests, ["picked": picked.map(\.rawValue).sorted().joined(separator: ",")])
        finish()
    }

    /// The offer is shown once, after the pages or on Skip, and never to Pro users; closing it lands on Discover.
    private func finish() {
        AppTelemetry.log(.onboardingCompleted, ["step": String(page)])
        guard !library.hasSeenLaunchPaywall, !purchases.isPro else {
            library.finishWelcome()
            return
        }
        library.markLaunchPaywallSeen()
        withAnimation { showOffer = true }
    }
}
