import SwiftUI

/// Keeps a living scene and a large clock on screen while the iPhone charges. Touch and tilt still work.
struct NightstandView: View {
    @State var theme: Theme?
    @Environment(ContentStore.self) private var content
    @Environment(PurchasesService.self) private var purchases
    @Environment(LibraryStore.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var showChargingGuide = false
    @State private var showControls = true
    @State private var dimmed = false
    @State private var battery = BatteryState()
    @State private var lockedTheme: Theme?
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let theme {
                ScenePreview(theme: theme, configuration: SceneConfiguration(), isActive: true)
                    .ignoresSafeArea()
                    .id(theme.id)
            }
            LinearGradient(colors: [.black.opacity(0.45), .clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea().allowsHitTesting(false)
            clock.allowsHitTesting(false)
            if dimmed { Color.black.opacity(0.55).ignoresSafeArea().allowsHitTesting(false) }
            if showControls { controls.transition(.opacity) }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { withAnimation { showControls.toggle() }; scheduleHide() }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            battery.start()
            AppTelemetry.log(.nightstandOpened)
            scheduleHide()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            battery.stop()
            hideTask?.cancel()
        }
        .sheet(item: $lockedTheme) { locked in ProPaywallView(source: .lockedScene, theme: locked) }
        .sheet(isPresented: $showChargingGuide) { ChargingAutomationGuide() }
    }

    private var clock: some View {
        TimelineView(.everyMinute) { context in
            let date = LockScreenClock.displayDate(context.date)
            VStack(spacing: 4) {
                Text(date, format: .dateTime.weekday(.wide).month().day())
                    .font(.title3.weight(.semibold))
                Text(LockScreenClock.timeText(date))
                    .font(.system(size: 120, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
                if battery.isCharging {
                    Label(battery.level.formatted(.percent.precision(.fractionLength(0))), systemImage: "bolt.fill")
                        .font(.headline).foregroundStyle(Design.accent)
                }
            }
            .foregroundStyle(.white.opacity(dimmed ? 0.7 : 0.95))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 3)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 70)
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44).background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel(Text("action.close"))
                Spacer()
                Button { showChargingGuide = true } label: {
                    Image(systemName: "bolt.badge.automatic").font(.headline).frame(width: 44, height: 44).background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel(Text("nightstand.auto.title"))
                .accessibilityIdentifier("nightstand.auto")
                Button { dimmed.toggle(); scheduleHide() } label: {
                    Image(systemName: dimmed ? "moon.fill" : "moon").font(.headline).frame(width: 44, height: 44).background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel(Text("nightstand.dim"))
            }
            .padding(.horizontal, 20).padding(.top, 12)
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text("nightstand.hint").font(.caption).foregroundStyle(.white.opacity(0.8))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(content.catalog.themes) { item in
                            Button { choose(item) } label: {
                                ArtworkView(theme: item).frame(width: 64, height: 96).clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(item.id == theme?.id ? Design.accent : .clear, lineWidth: 2))
                                    .overlay(alignment: .bottomTrailing) {
                                        if !item.isFree && !purchases.isPro {
                                            Image(systemName: "lock.fill").font(.system(size: 10)).padding(5).background(.black.opacity(0.5), in: Circle()).padding(4)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(item.displayTitle))
                        }
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 12).padding(.bottom, 12)
        }
    }

    private func choose(_ item: Theme) {
        scheduleHide()
        guard item.isFree || purchases.isPro else { lockedTheme = item; return }
        withAnimation { theme = item }
        library.setNightstandTheme(item.id)
    }

    /// Controls fade after a few seconds so the scene and clock own the screen; a double tap brings them back.
    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation { showControls = false }
        }
    }
}

/// iOS gives apps no charging trigger, so a personal Shortcuts automation opens Nightstand when the charger connects.
private struct ChargingAutomationGuide: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private let steps = ["nightstand.auto.step1", "nightstand.auto.step2", "nightstand.auto.step3", "nightstand.auto.step4"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("nightstand.auto.detail").foregroundStyle(Design.muted)
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, key in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)").font(.headline.monospacedDigit()).foregroundStyle(.black)
                                .frame(width: 32, height: 32).background(Design.accent, in: Circle())
                            Text(LocalizedStringKey(key)).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Design.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    HStack {
                        Text(verbatim: "screenmotion://nightstand").font(.callout.monospaced()).textSelection(.enabled)
                        Spacer()
                        Button("nightstand.auto.copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = "screenmotion://nightstand" }
                            .labelStyle(.iconOnly).frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 16).background(Design.surface, in: RoundedRectangle(cornerRadius: 16))
                    if let url = URL(string: "shortcuts://") {
                        PrimaryButton(title: "nightstand.auto.open", symbol: "arrow.up.forward.app") { openURL(url) }
                    }
                }
                .padding(Design.padding)
            }
            .background(Design.background)
            .navigationTitle("nightstand.auto.title").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("action.close") { dismiss() } } }
        }
        .onAppear { AppTelemetry.log(.chargingGuideViewed) }
    }
}

@MainActor @Observable final class BatteryState {
    private(set) var level: Double = 0
    private(set) var isCharging = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
        let center = NotificationCenter.default
        for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    private func refresh() {
        level = Double(max(0, UIDevice.current.batteryLevel))
        isCharging = [.charging, .full].contains(UIDevice.current.batteryState)
    }
}
