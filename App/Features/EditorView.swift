import SwiftUI

struct EditorView: View {
    let theme: Theme
    @State var configuration = SceneConfiguration()
    @Environment(LibraryStore.self) private var library
    @Environment(PurchasesService.self) private var purchases
    @State private var undoStack: [SceneConfiguration] = []
    @State private var advanced = false
    @State private var showExport = false
    @State private var isVisible = true
    @State private var saved = false
    @State private var audioPlayer = ThemeAudioPlayer()
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack(alignment: .top) {
                    ScenePreview(theme: theme, configuration: configuration, isActive: isVisible && !showExport)
                    VStack(spacing: 3) {
                        Text(LockScreenClock.displayDate(.now), format: .dateTime.weekday(.wide).month().day()).font(.subheadline.weight(.medium))
                        Text(LockScreenClock.timeText(LockScreenClock.displayDate(.now))).font(.system(size: 64, weight: .light, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                    }.padding(.top, 24).padding(.horizontal, 26).allowsHitTesting(false).accessibilityHidden(true)
                    if theme.remoteScene?.ambientAudioAsset != nil {
                        Button {
                            Task { await audioPlayer.toggle(theme: theme) }
                        } label: {
                            Image(systemName: audioPlayer.isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.55), in: Circle())
                                .padding(14)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .accessibilityLabel(Text(audioPlayer.isPlaying ? "audio.stop" : "audio.play"))
                        .accessibilityIdentifier("themeAudioToggle")
                    }
                    VStack { Spacer(); Label("editor.interact", systemImage: "hand.draw").font(.caption).padding(10).background(.black.opacity(0.4), in: Capsule()).padding(.bottom, 16) }.allowsHitTesting(false)
                }.frame(height: 430).clipShape(RoundedRectangle(cornerRadius: 30)).contentShape(Rectangle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(theme.displayTitle)).accessibilityHint(Text("editor.interact"))
                    .accessibilityIdentifier("scenePreview.\(theme.id)")
                VStack(alignment: .leading, spacing: 18) {
                    if let subtitle = theme.displaySubtitle {
                        Text(subtitle).font(.subheadline).foregroundStyle(Design.muted)
                    }
                    HStack { Text("editor.yourStyle").font(.title3.bold()); Spacer(); Button { if let previous = undoStack.popLast() { configuration = previous } } label: { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }.disabled(undoStack.isEmpty).accessibilityLabel(Text("action.undo")) }
                    Picker("editor.style", selection: Binding(get: { configuration.style }, set: { value in undoStack.append(configuration); configuration.style = value })) { Text("style.original").tag(0); Text("style.cool").tag(1); Text("style.warm").tag(2) }.pickerStyle(.segmented)
                    if theme.loopResource == nil { slider("editor.motion", value: $configuration.intensity) }
                    if theme.interaction?.supportsScoreMode == true {
                        Toggle("editor.scoreMode", isOn: $configuration.scoreMode)
                            .tint(Design.accent)
                            .accessibilityIdentifier("scoreModeToggle")
                            .onChange(of: configuration.scoreMode) { oldValue, _ in
                                var previous = configuration
                                previous.scoreMode = oldValue
                                undoStack.append(previous)
                            }
                    }
                    DisclosureGroup("editor.advanced", isExpanded: $advanced) {
                        VStack(spacing: 18) { if theme.loopResource == nil { slider("editor.particles", value: $configuration.particles) }; slider("editor.depth", value: $configuration.depth); slider("editor.zoom", value: $configuration.zoom, range: 1...1.6); Button("action.reset") { undoStack.append(configuration); configuration = SceneConfiguration() }.frame(minHeight: 44) }.padding(.top, 18)
                    }.tint(.white)
                }
                Text("platform.short").font(.caption).foregroundStyle(Design.muted)
            }.padding(Design.padding)
        }.background(Design.background).navigationTitle(theme.displayTitle).navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { library.toggleFavorite(theme.id) } label: { Image(systemName: library.favorites.contains(theme.id) ? "heart.fill" : "heart").frame(width: 44, height: 44) }.accessibilityLabel(Text("library.favorite")) }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button { library.save(theme, configuration: configuration); saved = true; AppTelemetry.log(.designSaved) } label: { Image(systemName: saved ? "bookmark.fill" : "bookmark").frame(width: 54, height: 56).background(Design.surface, in: RoundedRectangle(cornerRadius: 18)) }.accessibilityLabel(Text(saved ? "library.saved" : "library.save"))
                PrimaryButton(title: "editor.saveInstall", symbol: theme.isFree || purchases.isPro ? "arrow.down" : "lock.fill") { showExport = true }
            }.padding(.horizontal, Design.padding).padding(.vertical, 12).background(Design.background)
        }
        .onChange(of: configuration) { _, _ in saved = false }
        .onAppear { isVisible = true; AppTelemetry.log(.editorViewed) }.onDisappear { isVisible = false; audioPlayer.stop() }
        .sheet(isPresented: $showExport) { ExportView(theme: theme, configuration: configuration) }
        .sensoryFeedback(.success, trigger: saved)
    }
    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double> = 0...1) -> some View {
        VStack(spacing: 5) {
            HStack { Text(LocalizedStringKey(title)); Spacer(); Text(value.wrappedValue, format: .percent.precision(.fractionLength(0))).foregroundStyle(Design.muted) }.font(.subheadline)
            Slider(value: value, in: range, onEditingChanged: { editing in if editing { undoStack.append(configuration) } }).accessibilityLabel(Text(LocalizedStringKey(title)))
        }
    }
}
