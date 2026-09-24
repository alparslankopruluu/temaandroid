import SwiftUI

struct PackageView: View {
    let collection: ThemeCollection
    @Environment(PurchasesService.self) private var purchases
    @Environment(ContentStore.self) private var content
    @Environment(LibraryStore.self) private var library
    @State private var showPro = false
    @State private var iconURL: URL?
    @State private var busy = false
    @State private var message: String?
    @State private var selectedTheme: String = ""
    @State private var showWidgetGuide = false
    private var themes: [Theme] { content.catalog.themes.filter { $0.collection == collection } }
    private var selectedConfiguration: SceneConfiguration {
        library.designs.first(where: { $0.themeID == selectedTheme })?.configuration ?? .init()
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let theme = themes.first { ArtworkView(theme: theme).frame(height: 230).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 26)) }
                Text("package.subtitle").foregroundStyle(Design.muted)
                Text("package.icons").font(.title2.bold())
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(0..<24) { index in Image(uiImage: IconExportService.image(index: index, collection: collection, size: 128)).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityLabel(Text(LocalizedStringKey("icon." + String(index)))) }
                }
                if let iconURL { ShareLink(item: iconURL) { Label("icons.share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 50) } }
                else { PrimaryButton(title: busy ? "purchase.working" : "icons.export", symbol: "arrow.down") {
                    guard purchases.isPro else { showPro = true; return }
                    busy = true
                    Task {
                        do {
                            iconURL = try await IconExportService.export(collection: collection)
                            if let theme = themes.first(where: { $0.id == selectedTheme }) ?? themes.first {
                                library.markExported(.icons, themeID: theme.id, configuration: selectedConfiguration)
                            }
                        } catch { message = error.localizedDescription }
                        busy = false
                    }
                }.disabled(busy) }
                if let theme = themes.first(where: { $0.id == selectedTheme }) ?? themes.first {
                    NavigationLink("install.icons", destination: InstallView(kind: .icons, theme: theme, configuration: selectedConfiguration)).frame(minHeight: 44)
                }
                Text("package.widgets").font(.title2.bold())
                HStack { widgetTile("widget.date", symbol: "calendar"); widgetTile("widget.photo", symbol: "photo") }
                Text("widget.selectionHint").font(.subheadline).foregroundStyle(Design.muted)
                Picker("widget.theme", selection: $selectedTheme) { ForEach(themes) { theme in Text(theme.displayTitle).tag(theme.id) } }.pickerStyle(.menu)
                PrimaryButton(title: "widget.select", symbol: "plus") {
                    guard purchases.isPro else { showPro = true; return }
                    guard let theme = themes.first(where: { $0.id == selectedTheme }) ?? themes.first else { return }
                    Task {
                        do {
                            try await WidgetBridge.select(theme: theme, configuration: selectedConfiguration)
                            library.markExported(.widgets, themeID: theme.id, configuration: selectedConfiguration)
                            showWidgetGuide = true
                        } catch { message = error.localizedDescription }
                    }
                }
                if let message { Text(message).foregroundStyle(.orange).font(.footnote) }
            }.padding(Design.padding)
        }.background(Design.background).navigationTitle(LocalizedStringKey(collection.titleKey)).navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPro) { ProPaywallView() }
            .navigationDestination(isPresented: $showWidgetGuide) {
                if let theme = themes.first(where: { $0.id == selectedTheme }) ?? themes.first {
                    InstallView(kind: .widgets, theme: theme, configuration: selectedConfiguration)
                }
            }
            .onAppear { if selectedTheme.isEmpty { selectedTheme = themes.first?.id ?? "" } }
    }
    private func widgetTile(_ key: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 16) { Image(systemName: symbol).font(.largeTitle); Text(LocalizedStringKey(key)).font(.headline); Text(Date.now, format: .dateTime.month(.wide).day()).font(.caption) }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Design.tint(collection).opacity(0.16), in: RoundedRectangle(cornerRadius: 24))
    }
}
