import SwiftUI

struct ExportView: View {
    let theme: Theme
    let configuration: SceneConfiguration
    @Environment(LibraryStore.self) private var library
    @Environment(PurchasesService.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var service = ExportService()
#if DEBUG
    @State private var ad = RewardedAdService()
#endif
    @State private var format = ExportFormat.livePhoto
    @State private var error: String?
    @State private var exported: URL?
    @State private var showPro = false
    @State private var showGuide = false
    @State private var task: Task<Void, Never>?
    private var canExport: Bool {
#if DEBUG
        theme.isFree || purchases.isPro || library.rewards.contains(theme.id)
#else
        theme.isFree || purchases.isPro
#endif
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 18) {
                        ArtworkView(theme: theme).frame(width: 84, height: 112).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 8) { Text(theme.displayTitle).font(.title2.bold()); Text("export.description").font(.subheadline).foregroundStyle(Design.muted) }
                    }
                    if let exported {
                        Label("export.success", systemImage: "checkmark.circle.fill").font(.title2.bold()).foregroundStyle(Design.accent)
                        if format != .video { PrimaryButton(title: "install.title") { showGuide = true } }
                        ShareLink(item: exported) { Label("action.share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44) }
                    } else {
                        ForEach(ExportFormat.allCases) { item in
                            Button { format = item } label: {
                                ExportChoice(format: item, selected: format == item)

                            }.buttonStyle(.plain).disabled(service.isExporting).accessibilityAddTraits(format == item ? .isSelected : [])
                        }
                        if service.isExporting { ProgressView(value: service.progress); Button("action.cancel") { service.cancel() }.frame(minHeight: 44) }
                        else if canExport { PrimaryButton(title: "export.save", symbol: "arrow.down.to.line") { performExport() } }
                        else {
                            PrimaryButton(title: "pro.unlock", symbol: "sparkles") { showPro = true }
#if DEBUG
                            Button { task = Task { do { try await ad.playTest(); library.grantReward(theme.id) } catch { self.error = L("ad.cancelled") } } } label: { Label(ad.running ? "ad.playing" : "ad.watch", systemImage: "play.rectangle").frame(maxWidth: .infinity, minHeight: 50) }.disabled(ad.running)
                            if ad.running { ProgressView(); Button("action.cancel") { task?.cancel() } }
                            Text("ad.testNotice").font(.caption).foregroundStyle(Design.muted)
#endif
                        }
                    }
                    if let error { Text(error).font(.subheadline).foregroundStyle(.orange).accessibilityIdentifier("exportError") }
                    Text("platform.detail").font(.footnote).foregroundStyle(Design.muted)
                }.padding(Design.padding)
            }.background(Design.background).navigationTitle("export.title").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("action.close") { dismiss() }.disabled(service.isExporting).accessibilityIdentifier("action.close") } }
                .sheet(isPresented: $showPro) { ProPaywallView() }
                .navigationDestination(isPresented: $showGuide) { InstallView(kind: .wallpaper, theme: theme, configuration: configuration) }
        }.interactiveDismissDisabled(service.isExporting).onDisappear { task?.cancel() }
    }
    private func performExport() {
        error = nil
        task = Task {
            do {
                exported = try await service.export(theme: theme, configuration: configuration, format: format)
                library.save(theme, configuration: configuration)
                if format != .video {
                    library.markExported(.wallpaper, themeID: theme.id, configuration: configuration)
                }
#if DEBUG
                if !theme.isFree && !purchases.isPro { library.consumeReward(theme.id) }
#endif
            } catch { self.error = error.localizedDescription }
        }
    }
}

private struct ExportChoice: View {
    let format: ExportFormat
    let selected: Bool
    private var symbol: String {
        switch format { case .still: "photo"; case .video: "film"; case .livePhoto: "livephoto" }
    }
    var body: some View {
        HStack {
            Image(systemName: symbol).font(.title2).frame(width: 36)
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey(format.titleKey)).font(.headline)
                Text(LocalizedStringKey(format.hintKey)).font(.caption).foregroundStyle(Design.muted)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Design.accent : Design.muted)
        }.padding(18).background(Design.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}
