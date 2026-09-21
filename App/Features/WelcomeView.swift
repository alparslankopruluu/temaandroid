import SwiftUI

struct WelcomeView: View {
    @Environment(LibraryStore.self) private var library
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 48.0
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if let theme = ThemeCatalog.bundled.themes.first {
                    ScenePreview(theme: theme, configuration: SceneConfiguration()).ignoresSafeArea()
                }
                LinearGradient(colors: [.clear, .black.opacity(0.2), Design.background], startPoint: .top, endPoint: .bottom).allowsHitTesting(false).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Text("SCREENMOTION").font(.system(.caption, design: .monospaced).weight(.semibold)).tracking(4); Spacer(); Button("action.skip") { library.finishWelcome() }.frame(minHeight: 44) }.padding(.top, 12)
                    Spacer()
                    Label("welcome.interact", systemImage: "hand.draw").font(.subheadline).padding(.horizontal, 15).padding(.vertical, 10).background(.ultraThinMaterial, in: Capsule())
                    Text("welcome.title").font(.system(size: titleSize, weight: .bold, design: .rounded)).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
                    Text("welcome.subtitle").font(.body).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                    PrimaryButton(title: "welcome.start") { library.finishWelcome() }.accessibilityIdentifier("startExploring")
                    Text("welcome.note").font(.caption).foregroundStyle(Design.muted).frame(maxWidth: .infinity)
                }.padding(Design.padding).frame(maxHeight: proxy.size.height)
            }
        }.background(Design.background)
    }
}
