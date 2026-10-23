import SwiftUI

/// iOS 26 can turn a still image into a Spatial Scene that shifts as the iPhone tilts. iOS owns the effect;
/// ScreenMotion saves the still and walks through each system step.
struct SpatialGuideView: View {
    var theme: Theme?
    var configuration = SceneConfiguration()
    @Environment(PurchasesService.self) private var purchases
    @State private var service = ExportService()
    @State private var saved = false
    @State private var error: String?
    @State private var showPro = false

    /// Spatial Scene exists from iOS 26; older systems never see the entry points, since a still alone is not a live wallpaper.
    static var isSupported: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }
    private var supported: Bool { Self.isSupported }
    private let steps: [(symbol: String, key: String)] = [
        ("photo.on.rectangle", "spatial.step.1"),
        ("gearshape", "spatial.step.2"),
        ("cube.transparent", "spatial.step.3"),
        ("iphone.gen3.radiowaves.left.and.right", "spatial.step.4")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("spatial.title").font(.system(.title, design: .rounded, weight: .bold))
                Text("spatial.subtitle").foregroundStyle(Design.muted)
                if !supported {
                    Label("spatial.requires", systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.orange)
                }
                if let theme {
                    if saved {
                        Label("spatial.saved", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(Design.accent)
                    } else if service.isExporting {
                        ProgressView(value: service.progress)
                    } else if theme.isFree || purchases.isPro {
                        PrimaryButton(title: "spatial.saveStill", symbol: "arrow.down.to.line") { Task { await save(theme) } }
                    } else {
                        PrimaryButton(title: "pro.unlock", symbol: "sparkles") { showPro = true }
                    }
                }
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 16) {
                        Text("\(index + 1)").font(.headline.monospacedDigit()).frame(width: 32, height: 32)
                            .background(Design.accent.opacity(0.16), in: Circle()).foregroundStyle(Design.accent)
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: step.symbol).font(.title2).foregroundStyle(Design.accent)
                            Text(LocalizedStringKey(step.key)).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                    .background(Design.surface, in: RoundedRectangle(cornerRadius: 22))
                }
                if let error { Text(error).font(.subheadline).foregroundStyle(.orange) }
                Text("spatial.note").font(.footnote).foregroundStyle(Design.muted)
            }
            .padding(Design.padding)
        }
        .background(Design.background)
        .navigationTitle("spatial.navTitle")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPro) { ProPaywallView(source: .export, theme: theme) }
        .onAppear { AppTelemetry.log(.tiltGuideViewed) }
    }

    private func save(_ theme: Theme) async {
        error = nil
        do {
            _ = try await service.export(theme: theme, configuration: configuration, format: .still)
            saved = true
        } catch {
            AppTelemetry.record(.export, underlying: error)
            self.error = error.localizedDescription
        }
    }
}
