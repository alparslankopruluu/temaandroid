import SwiftUI
import PhotosUI
import AVFoundation
import StoreKit
import UniformTypeIdentifiers

/// Turns the user's own clip into a Live Photo wallpaper. The first conversions are free; Pro removes the limit.
struct VideoLiveView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PurchasesService.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @State private var pickerItem: PhotosPickerItem?
    @State private var clip: URL?
    @State private var duration = 0.0
    @State private var start = 0.0
    @State private var player = AVPlayer()
    @State private var loopObserver: Any?
    @State private var loading = false
    @State private var showCamera = false
    @State private var showPro = false
    @State private var showGuide = false
    @State private var exported = false
    @State private var error: String?
    @State private var service = ExportService()
    @State private var fit = false
    private static let window = 3.0

    private var canConvert: Bool { purchases.isPro || library.freeVideoConversionsLeft > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let clip {
                    editor(clip)
                } else {
                    intro
                }
                if let error {
                    Text(error).font(.subheadline).foregroundStyle(.orange).accessibilityIdentifier("videoError")
                }
            }
            .padding(Design.padding)
        }
        .background(Design.background)
        .navigationTitle("video.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("action.close") { dismiss() }.disabled(service.isExporting).accessibilityIdentifier("video.close") } }
        .interactiveDismissDisabled(service.isExporting)
        .onChange(of: pickerItem) { _, item in Task { await load(item) } }
        .sheet(isPresented: $showCamera) {
            CameraRecorder { url in Task { await use(url) } }.ignoresSafeArea()
        }
        .sheet(isPresented: $showPro) { ProPaywallView(source: .video) }
        .navigationDestination(isPresented: $showGuide) { InstallView(kind: .wallpaper) }
        .onAppear { AppTelemetry.log(.videoPickerViewed) }
#if DEBUG
        .task {
            // UI tests cannot drive the out-of-process Photos picker; this loads a bundled sample instead.
            if clip == nil, let id = UserDefaults.standard.string(forKey: "demo-video"),
               let url = Bundle.main.url(forResource: "loop-\(id)", withExtension: "mp4") { await use(url) }
        }
#endif
        .onDisappear { player.pause() }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "livephoto.play").font(.system(size: 44)).foregroundStyle(Design.accent)
            Text("video.headline").font(.system(.title, design: .rounded, weight: .bold))
            Text("video.subtitle").foregroundStyle(Design.muted)
            quota
            PhotosPicker(selection: $pickerItem, matching: .videos, preferredItemEncoding: .current) {
                Label("video.choose", systemImage: "photo.on.rectangle")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 56).foregroundStyle(.black)
                    .background(Design.accent, in: RoundedRectangle(cornerRadius: 18))
            }
            .accessibilityIdentifier("video.choose")
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showCamera = true } label: {
                    Label("video.record", systemImage: "video").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
            }
            if loading { ProgressView().frame(maxWidth: .infinity) }
            Text("video.note").font(.footnote).foregroundStyle(Design.muted)
        }
    }

    @ViewBuilder private var quota: some View {
        if !purchases.isPro {
            Label(String(format: L("video.freeLeft"), library.freeVideoConversionsLeft), systemImage: "gift")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Design.surface, in: Capsule())
        }
    }

    private func editor(_ clip: URL) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // The preview frames the clip exactly as the Live Photo will: cropped to fill, or whole over a blurred fill.
            ZStack {
                if fit { PlayerLayerView(player: player, gravity: .resizeAspectFill).blur(radius: 24).opacity(0.85) }
                PlayerLayerView(player: player, gravity: fit ? .resizeAspect : .resizeAspectFill)
            }
                .aspectRatio(9 / 16, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .overlay(alignment: .top) { LockScreenClock(compact: false).padding(.top, 24).allowsHitTesting(false) }
            if exported {
                Label("export.success", systemImage: "checkmark.circle.fill").font(.title2.bold()).foregroundStyle(Design.accent)
                PrimaryButton(title: "install.title") { showGuide = true }
                Button("video.another") { reset() }.frame(maxWidth: .infinity, minHeight: 44)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("video.pickMoment").font(.headline)
                    Slider(value: $start, in: 0...max(0.01, duration - Self.window)) { editing in
                        if !editing { playWindow() }
                    }
                    .disabled(duration <= Self.window || service.isExporting)
                    .accessibilityLabel(Text("video.pickMoment"))
                    Text(String(format: L("video.window"), start, min(duration, start + Self.window)))
                        .font(.caption.monospacedDigit()).foregroundStyle(Design.muted)
                }
                Picker("video.framing", selection: $fit) {
                    Text("video.fill").tag(false)
                    Text("video.fit").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(service.isExporting)
                .accessibilityIdentifier("video.framing")
                quota
                if service.isExporting {
                    ProgressView(value: service.progress)
                    Button("action.cancel") { service.cancel() }.frame(minHeight: 44)
                } else if canConvert {
                    PrimaryButton(title: "video.save", symbol: "livephoto") { Task { await convert(clip) } }
                } else {
                    PrimaryButton(title: "pro.unlock", symbol: "sparkles") { showPro = true }
                    Text("video.limitReached").font(.footnote).foregroundStyle(Design.muted)
                }
                Button("video.chooseOther") { reset() }.frame(maxWidth: .infinity, minHeight: 44).disabled(service.isExporting)
            }
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        loading = true
        error = nil
        defer { loading = false }
        do {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { throw ExportFailure.renderer }
            await use(movie.url)
        } catch {
            AppTelemetry.record(.videoImport, underlying: error)
            self.error = L("video.error.load")
        }
    }

    private func use(_ url: URL) async {
        let asset = AVURLAsset(url: url)
        guard let seconds = try? await asset.load(.duration).seconds, seconds > 0.5 else {
            error = L("video.error.load")
            return
        }
        duration = seconds
        start = 0
        exported = false
        clip = url
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        player.isMuted = true
        playWindow()
    }

    /// Plays only the chosen three seconds, on repeat, so the preview matches the Live Photo.
    private func playWindow() {
        if let loopObserver { player.removeTimeObserver(loopObserver) }
        let begin = CMTime(seconds: start, preferredTimescale: 600)
        let end = CMTime(seconds: min(duration, start + Self.window), preferredTimescale: 600)
        player.seek(to: begin, toleranceBefore: .zero, toleranceAfter: .zero)
        loopObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: end)], queue: .main) { [player] in
            player.seek(to: begin, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player.play()
    }

    private func convert(_ clip: URL) async {
        error = nil
        player.pause()
        AppTelemetry.log(.exportStarted, ["kind": "video"])
        do {
            _ = try await service.exportClip(clip, start: start, fit: fit)
            if !purchases.isPro { library.recordVideoConversion() }
            AppTelemetry.log(.videoConverted, ["pro": purchases.isPro ? "1" : "0", "framing": fit ? "fit" : "fill"])
            AppTelemetry.log(.exportCompleted, ["kind": "video"])
            exported = true
            // Rating after the 1st and 3rd save; the notification question waits for the 2nd so prompts never stack.
            let saves = library.recordSuccessfulExport()
            if [1, 3].contains(saves) {
                AppTelemetry.log(.reviewRequested)
                requestReview()
            } else if saves == 2 {
                Task { await PushService.shared.requestPermission(source: "second_save") }
            }
        } catch {
            AppTelemetry.log(.exportFailed, ["kind": "video", "reason": ExportFailure.reason(error)])
            AppTelemetry.record(.export, underlying: error)
            self.error = error.localizedDescription
            playWindow()
        }
    }

    private func reset() {
        player.pause()
        clip = nil
        pickerItem = nil
        exported = false
    }
}

/// An AVPlayerLayer with an explicit gravity; SwiftUI's VideoPlayer always fits and adds playback chrome.
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let gravity: AVLayerVideoGravity

    final class LayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
    }

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.playerLayer?.player = player
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {
        view.playerLayer?.videoGravity = gravity
    }
}

/// Copies the picked movie into temporary storage; Photos only lends the file for the duration of the import.
private struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("clip-\(UUID().uuidString).\(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

/// Records a short clip with the system camera; SwiftUI has no native capture view.
private struct CameraRecorder: UIViewControllerRepresentable {
    let onRecorded: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoMaximumDuration = 10
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraRecorder
        init(_ parent: CameraRecorder) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL { parent.onRecorded(url) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
