import SwiftUI
import RevenueCat

struct ProPaywallView: View {
    @Environment(PurchasesService.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var offering: Offering?
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
                NativePaywallView(offering: offering)
            } else {
                NavigationStack {
                    ContentUnavailableView {
                        Label("purchase.unavailable", systemImage: "wifi.exclamationmark")
                    } actions: {
                        Button("action.retry") { Task { await loadOffering() } }
                            .buttonStyle(.borderedProminent)
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
            AppTelemetry.log(.proPaywallViewed)
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
            offering = current?.availablePackages.isEmpty == false ? current : nil
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
    @State private var busy = false
    @State private var selected: Package?

    private var packages: [Package] {
        offering.availablePackages.sorted {
            if $0.packageType == .annual { return true }
            if $1.packageType == .annual { return false }
            return $0.identifier < $1.identifier
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(Design.accent)
                            .accessibilityHidden(true)
                        Text("pro.title").font(.largeTitle.bold())
                        Text("pro.subtitle").font(.title3).foregroundStyle(Design.muted)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        benefit("pro.benefit.scenes", symbol: "photo.stack")
                        benefit("pro.benefit.packs", symbol: "app.dashed")
                        benefit("pro.benefit.exports", symbol: "arrow.down.circle")
                    }
                    .padding(18)
                    .background(Design.surface, in: RoundedRectangle(cornerRadius: 22))

                    ForEach(packages) { package in
                        Button {
                            selected = package
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text(package.packageType == .annual ? "pro.yearly" : "pro.monthly")
                                            .font(.headline)
                                        if package.packageType == .annual {
                                            Text("pro.mostPopular")
                                                .font(.caption.bold())
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .foregroundStyle(.black)
                                                .background(Design.accent, in: Capsule())
                                        }
                                    }
                                    Text(package.storeProduct.localizedPriceString)
                                        .font(.subheadline)
                                        .foregroundStyle(Design.muted)
                                }
                                Spacer()
                                Image(systemName: selected?.id == package.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected?.id == package.id ? Design.accent : Design.muted)
                            }
                            .padding(18)
                            .background(Design.surface, in: RoundedRectangle(cornerRadius: 20))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selected?.id == package.id ? Design.accent : .clear, lineWidth: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    PrimaryButton(title: busy ? "purchase.working" : "pro.continue", symbol: "sparkles") {
                        Task { await purchase() }
                    }
                    .disabled(busy || selected == nil)

                    Text("pro.terms")
                        .font(.caption)
                        .foregroundStyle(Design.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Button("purchase.restore") {
                        Task { await purchases.restore() }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(purchases.busy)

                    HStack {
                        if let url = URL(string: "https://screenmotion-legal.kprl884.workers.dev/terms") {
                            Link("legal.terms", destination: url)
                        }
                        Text("|").foregroundStyle(Design.muted)
                        if let url = URL(string: "https://screenmotion-legal.kprl884.workers.dev/privacy") {
                            Link("legal.privacy", destination: url)
                        }
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)

                    if let message = purchases.message {
                        Text(LocalizedStringKey(message))
                            .font(.footnote)
                            .foregroundStyle(Design.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(Design.padding)
            }
            .background(Design.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("action.close") { dismiss() } } }
        }
        .onAppear {
            if selected == nil {
                selected = packages.first { $0.packageType == .annual } ?? packages.first
            }
        }
    }

    private func benefit(_ key: String, symbol: String) -> some View {
        Label {
            Text(LocalizedStringKey(key)).font(.subheadline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Design.accent)
        }
    }

    private func purchase() async {
        guard let selected, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            if try await purchases.purchase(selected) { dismiss() }
        } catch {
            AppTelemetry.log(.proPurchaseFailed)
            purchases.message = "purchase.failed"
        }
    }
}
