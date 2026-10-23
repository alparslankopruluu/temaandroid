import SwiftUI
import RevenueCat

struct ProPaywallView: View {
    var source: PaywallSource = .settings
    /// The scene that brought the user here; it becomes the living background.
    var theme: Theme?
    /// Offered on locked scenes because every preview stays free.
    var onPreview: (() -> Void)?
    @Environment(PurchasesService.self) private var purchases
    @Environment(ContentStore.self) private var content
    @Environment(\.dismiss) private var dismiss
    @State private var offering: Offering?
    @State private var eligibility: [String: Bool] = [:]
    @State private var loading = true
    @State private var requestID = UUID()

    var body: some View {
        Group {
            if loading {
                ZStack {
                    Design.background.ignoresSafeArea()
                    ProgressView()
                }
            } else if let offering {
                NativePaywallView(offering: offering, eligibility: eligibility, source: source,
                                  theme: theme ?? ThemeCatalog.offer(in: content.catalog.themes),
                                  sceneCount: content.catalog.themes.count,
                                  loopCount: content.catalog.themes.filter { $0.loopResource != nil }.count,
                                  onPreview: onPreview)
            } else {
                NavigationStack {
                    ContentUnavailableView {
                        Label("purchase.unavailable", systemImage: "wifi.exclamationmark")
                    } actions: {
                        Button("action.retry") { Task { await loadOffering() } }
                            .buttonStyle(.borderedProminent)
                        if let onPreview {
                            // A failed store load must never take away the free preview.
                            Button("pro.previewFirst") { dismiss(); onPreview() }
                                .accessibilityIdentifier("pro.previewFirst")
                        }
                    }
                    .background(Design.background)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("action.close", systemImage: "xmark", action: dismiss.callAsFunction)
                        }
                    }
                }
            }
        }
        .task {
            AppTelemetry.log(.proPaywallViewed, ["source": source.rawValue])
            await loadOffering()
        }
    }

    private func loadOffering() async {
        let currentRequest = UUID()
        requestID = currentRequest
        loading = true
        offering = nil

        let timeout = Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, requestID == currentRequest, loading else { return }
            loading = false
        }
        defer { timeout.cancel() }

        await purchases.load()
        do {
            let current = try await Purchases.shared.offerings().current
            guard requestID == currentRequest else { return }
            if let current, !current.availablePackages.isEmpty {
                offering = current
                loading = false
                // Plans show at once; the trial badge and timeline appear when eligibility arrives.
                let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: current.availablePackages)
                guard requestID == currentRequest else { return }
                eligibility = Dictionary(uniqueKeysWithValues: result.map { ($0.key.identifier, $0.value.status == .eligible) })
            }
            loading = false
        } catch {
            guard requestID == currentRequest else { return }
            loading = false
        }
    }
}

private struct NativePaywallView: View {
    @Environment(PurchasesService.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    let offering: Offering
    let eligibility: [String: Bool]
    let source: PaywallSource
    let theme: Theme?
    let sceneCount: Int
    let loopCount: Int
    let onPreview: (() -> Void)?
    @State private var busy = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: Package?

    /// Yearly first (the default), then monthly, then lifetime; anything unknown keeps a stable order at the end.
    private var packages: [Package] {
        let rank: (Package) -> Int = { [.annual: 0, .monthly: 1, .lifetime: 2][$0.packageType] ?? 3 }
        return offering.availablePackages.sorted { (rank($0), $0.identifier) < (rank($1), $1.identifier) }
    }

    private var yearlySavings: Int? {
        guard let yearly = packages.first(where: { $0.packageType == .annual })?.storeProduct.price,
              let monthly = packages.first(where: { $0.packageType == .monthly })?.storeProduct.price else { return nil }
        return PaywallMath.yearlySavingsPercent(yearly: yearly, monthly: monthly)
    }

    /// A free trial is shown only when StoreKit offers one and the user can still redeem it.
    private func trial(for package: Package) -> StoreProductDiscount? {
        guard let discount = package.storeProduct.introductoryDiscount,
              discount.paymentMode == .freeTrial,
              eligibility[package.identifier] ?? false else { return nil }
        return discount
    }

    private var selectedTrial: StoreProductDiscount? { selected.flatMap(trial(for:)) }

    private func trialDays(_ trial: StoreProductDiscount) -> Int {
        let period = trial.subscriptionPeriod
        switch period.unit {
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        default: return period.value
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                VStack(alignment: .leading, spacing: 8) {
                    Text("pro.title").font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("pro.subtitle").font(.body).foregroundStyle(Design.muted)
                }
                VStack(alignment: .leading, spacing: 12) {
                    benefit(String(format: L("pro.benefit.scenes"), sceneCount, loopCount), symbol: "play.rectangle.on.rectangle", order: 0)
                    benefit("pro.benefit.video", symbol: "livephoto", order: 1)
                    benefit("pro.benefit.packs", symbol: "app.dashed", order: 2)
                    benefit("pro.benefit.exports", symbol: "arrow.down.circle", order: 3)
                }
                ForEach(packages) { package in planCard(package) }
                if let selectedTrial, let selected { timeline(trial: selectedTrial, package: selected) }
                if let onPreview {
                    Button {
                        AppTelemetry.log(.proPreviewChosen, ["source": source.rawValue])
                        dismiss()
                        onPreview()
                    } label: {
                        Text("pro.previewFirst").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityIdentifier("pro.previewFirst")
                }
                Text(selected?.packageType == .lifetime ? "pro.terms.lifetime" : "pro.terms").font(.caption).foregroundStyle(Design.muted)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                HStack(spacing: 14) {
                    Button("purchase.restore") { Task { await purchases.restore() } }.disabled(purchases.busy)
                    if let url = URL(string: "https://screenmotion-legal.kprl884.workers.dev/terms") { Link("legal.terms", destination: url) }
                    if let url = URL(string: "https://screenmotion-legal.kprl884.workers.dev/privacy") { Link("legal.privacy", destination: url) }
                }
                .font(.footnote).frame(maxWidth: .infinity, minHeight: 44)
                if let message = purchases.message {
                    Text(LocalizedStringKey(message)).font(.footnote).foregroundStyle(Design.muted).frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Design.padding)
            .padding(.bottom, 24)
        }
        .background(Design.background)
        .ignoresSafeArea(edges: .top)
        // The call to action and what it costs stay on screen while the plans scroll.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                PrimaryButton(title: busy ? "purchase.working" : (selectedTrial == nil ? "pro.continue" : "pro.startTrial"),
                              symbol: "sparkles") { Task { await purchase() } }
                    .disabled(busy || selected == nil)
                    .overlay { if !reduceMotion && !busy { ShineSweep().clipShape(RoundedRectangle(cornerRadius: 18)).allowsHitTesting(false) } }
                if let selectedTrial, let selected {
                    Text(String(format: L("pro.trial.then"), trialDays(selectedTrial), selected.storeProduct.localizedPriceString))
                        .font(.footnote.weight(.medium)).foregroundStyle(Design.accent).multilineTextAlignment(.center)
                } else if selected?.packageType == .lifetime {
                    Text("pro.lifetime.note").font(.footnote.weight(.medium)).foregroundStyle(Design.accent)
                }
            }
            .padding(.horizontal, Design.padding).padding(.top, 12).padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(Design.background.shadow(.drop(color: .black.opacity(0.6), radius: 12, y: -6)))
        }
        .overlay(alignment: .topTrailing) {
            Button {
                AppTelemetry.log(.proPaywallClosed, ["source": source.rawValue])
                dismiss()
            } label: {
                Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .padding(.trailing, 16).padding(.top, 8)
            .accessibilityLabel(Text("action.close"))
            .accessibilityIdentifier("action.close")
        }
        .onAppear {
            if selected == nil {
                selected = packages.first { $0.packageType == .annual } ?? packages.first
            }
            if reduceMotion { appeared = true } else { withAnimation(.spring(duration: 0.6)) { appeared = true } }
        }
    }

    private var header: some View {
        ZStack(alignment: .bottom) {
            if let theme {
                ScenePreview(theme: theme, configuration: SceneConfiguration())
            } else {
                Design.surface
            }
            LinearGradient(colors: [.clear, Design.background], startPoint: .center, endPoint: .bottom)
        }
        .frame(height: 250)
        .clipped()
        .padding(.horizontal, -Design.padding)
        .accessibilityHidden(true)
    }

    private func planCard(_ package: Package) -> some View {
        let isSelected = selected?.id == package.id
        let product = package.storeProduct
        let annual = package.packageType == .annual
        let plan: (title: String, price: String) = switch package.packageType {
        case .annual: ("pro.yearly", "pro.price.yearly")
        case .lifetime: ("pro.lifetime", "pro.price.lifetime")
        default: ("pro.monthly", "pro.price.monthly")
        }
        return Button {
            selected = package
            AppTelemetry.log(.proPlanSelected, ["source": source.rawValue, "plan": plan.title])
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(plan.title)).font(.headline)
                        if let trial = trial(for: package) {
                            Text(String(format: L("pro.trial.badge"), trialDays(trial)))
                                .font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                                .foregroundStyle(.black).background(Design.accent, in: Capsule())
                        } else if annual {
                            Text("pro.mostPopular").font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                                .foregroundStyle(.black).background(Design.accent, in: Capsule())
                        }
                    }
                    // The billed amount is the most prominent price on the card (App Review 3.1.2).
                    Text(String(format: L(plan.price), product.localizedPriceString))
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                if annual {
                    // Savings and the weekly figure share the trailing column so neither is squeezed out by long plan names.
                    VStack(alignment: .trailing, spacing: 6) {
                        if let yearlySavings {
                            Text(String(format: L("pro.save"), yearlySavings)).font(.caption.bold()).lineLimit(1)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .overlay(Capsule().stroke(Design.accent, lineWidth: 1)).foregroundStyle(Design.accent)
                        }
                        if let weekly = product.localizedPricePerWeek {
                            Text(String(format: L("pro.price.perWeek"), weekly)).font(.caption).foregroundStyle(Design.muted)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .fixedSize()
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Design.accent : Design.muted)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(16)
            .background(Design.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Design.accent : .clear, lineWidth: 2) }
            .scaleEffect(isSelected || reduceMotion ? 1 : 0.97)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func timeline(trial: StoreProductDiscount, package: Package) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            step("lock.open.fill", title: "pro.timeline.today", detail: "pro.timeline.todayDetail")
            step("calendar.badge.clock", title: "pro.timeline.charge",
                 detail: String(format: L("pro.timeline.chargeDetail"), package.storeProduct.localizedPriceString))
        }
        .padding(16)
        .background(Design.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
    }

    private func step(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Design.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold))
                Text(LocalizedStringKey(detail)).font(.caption).foregroundStyle(Design.muted)
            }
        }
    }

    /// Benefits slide in one after another the first time the offer appears.
    private func benefit(_ key: String, symbol: String, order: Int) -> some View {
        Label {
            Text(LocalizedStringKey(key)).font(.subheadline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Design.accent)
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -16)
        .animation(reduceMotion ? nil : .spring(duration: 0.5).delay(0.15 + Double(order) * 0.08), value: appeared)
    }

    private func purchase() async {
        guard let selected, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            if try await purchases.purchase(selected, source: source) { dismiss() }
        } catch {
            AppTelemetry.log(.proPurchaseFailed, ["source": source.rawValue])
            AppTelemetry.record(.purchase, underlying: error)
            purchases.message = "purchase.failed"
        }
    }
}

/// A soft band of light that crosses the call to action every few seconds to draw the eye without moving the layout.
private struct ShineSweep: View {
    private static let period = 2.8
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            GeometryReader { proxy in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
                // The band crosses during the first 40 % of each period, then rests.
                let progress = min(1, phase / 0.4)
                LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * 0.35)
                    .rotationEffect(.degrees(18))
                    .offset(x: -proxy.size.width * 0.4 + progress * proxy.size.width * 1.45)
                    .blendMode(.plusLighter)
            }
        }
        .accessibilityHidden(true)
    }
}

enum PaywallMath {
    /// Yearly savings against twelve months of the monthly plan, rounded down so the claim is never overstated;
    /// nil below 10 %, where a badge would read as noise.
    static func yearlySavingsPercent(yearly: Decimal, monthly: Decimal) -> Int? {
        guard monthly > 0, yearly > 0 else { return nil }
        var ratio = (1 - yearly / (monthly * 12)) * 100
        var floored = Decimal()
        NSDecimalRound(&floored, &ratio, 0, .down)
        let percent = NSDecimalNumber(decimal: floored).intValue
        return percent >= 10 ? percent : nil
    }
}
