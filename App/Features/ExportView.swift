import SwiftUI
import StoreKit

struct ExportView: View {
    let theme: Theme
    let configuration: SceneConfiguration
    @Environment(LibraryStore.self) private var library
    @Environment(PurchasesService.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @State private var permissionDenied = false
    @State private var service = ExportService()
#if DEBUG
    @State private var ad = RewardedAdService()
#endif
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
                        PrimaryButton(title: "install.title") { showGuide = true }
                        // The "theme saved" moment: matching icons, Home and Lock Screen widgets for the same world.
                        NavigationLink { PackageView(collection: theme.collection) } label: {
                            Label("export.completeLook", systemImage: "square.grid.3x3.square")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                                .background(Design.surface, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("export.completeLook")
                        .simultaneousGesture(TapGesture().onEnded { AppTelemetry.log(.completeLookOpened, ["scene": theme.id]) })
                        if SpatialGuideView.isSupported {
                            NavigationLink { SpatialGuideView(theme: theme, configuration: configuration) } label: {
                                Label("spatial.entry", systemImage: "cube.transparent").frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                        ShareLink(item: exported) { Label("action.share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44) }
                    } else {
                        Label("export.hint.livePhoto", systemImage: "livephoto").font(.headline)
                            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Design.surface, in: RoundedRectangle(cornerRadius: 20))
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
                    if permissionDenied, let settings = URL(string: UIApplication.openSettingsURLString) {
                        Button("export.openSettings") { openURL(settings) }.frame(maxWidth: .infinity, minHeight: 44)
                    }
                    Text("platform.detail").font(.footnote).foregroundStyle(Design.muted)
                }.padding(Design.padding)
            }.background(Design.background).navigationTitle("export.title").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("action.close") { dismiss() }.disabled(service.isExporting).accessibilityIdentifier("action.close") } }
                .sheet(isPresented: $showPro) { ProPaywallView(source: .export, theme: theme) }
                .navigationDestination(isPresented: $showGuide) { InstallView(kind: .wallpaper, theme: theme, configuration: configuration) }
        }.interactiveDismissDisabled(service.isExporting).onDisappear { task?.cancel() }
    }
    private func performExport() {
        error = nil
        permissionDenied = false
        AppTelemetry.log(.exportStarted, ["kind": theme.loopResource == nil ? "scene" : "loop"])
        task = Task {
            do {
                exported = try await service.export(theme: theme, configuration: configuration, format: .livePhoto)
                AppTelemetry.log(.exportCompleted, ["kind": theme.loopResource == nil ? "scene" : "loop"])
                library.save(theme, configuration: configuration)
                // Rating after the 1st and 3rd save; the notification question waits for the 2nd so prompts never stack.
            let saves = library.recordSuccessfulExport()
            if [1, 3].contains(saves) {
                AppTelemetry.log(.reviewRequested)
                requestReview()
            } else if saves == 2 {
                Task { await PushService.shared.requestPermission(source: "second_save") }
            }
                library.markExported(.wallpaper, themeID: theme.id, configuration: configuration)
#if DEBUG
                if !theme.isFree && !purchases.isPro { library.consumeReward(theme.id) }
#endif
            } catch {
                AppTelemetry.log(.exportFailed, ["reason": ExportFailure.reason(error)])
                AppTelemetry.record(.export, underlying: error)
                if case ExportFailure.permission = error { permissionDenied = true }
                self.error = error.localizedDescription
            }
        }
    }
}
