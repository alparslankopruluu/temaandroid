import Foundation
import Observation

@MainActor @Observable final class ContentStore {
    private(set) var catalog = ThemeCatalog.bundled
    private(set) var source: DynamicContentSource = .bundled

    @ObservationIgnored private let service: DynamicContentService?
    @ObservationIgnored private let assetCache: RemoteAssetCache

    init(bundle: Bundle = .main) {
        let cacheRoot = URL.cachesDirectory.appending(path: "remote-content", directoryHint: .isDirectory)
        assetCache = RemoteAssetCache(directory: cacheRoot.appending(path: "assets", directoryHint: .isDirectory))
        guard let bundledURL = bundle.url(forResource: "remote-content", withExtension: "json"),
              let bundledData = try? Data(contentsOf: bundledURL) else {
            service = nil
            return
        }
        let configured = bundle.object(forInfoDictionaryKey: "RemoteContentManifestURL") as? String
        let remoteURL = configured.flatMap(URL.init(string:)).flatMap {
            ValidatedRemoteContent.isSafeHTTPSBaseURL($0) ? $0 : nil
        }
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        service = DynamicContentService(
            bundledData: bundledData,
            remoteManifestURL: remoteURL,
            cacheURL: cacheRoot.appending(path: "last-known-good.json"),
            currentAppVersion: appVersion
        )
    }

    func refresh() async {
        guard let service, let snapshot = try? await service.load() else { return }
        let locale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        var themes: [(theme: Theme, order: Int)] = []
        let items = Dictionary(uniqueKeysWithValues: snapshot.content.manifest.items.map { ($0.id, $0) })

        for (index, base) in ThemeCatalog.bundled.themes.enumerated() {
            guard let item = items[base.id] else {
                themes.append((base, 10_000 + index))
                continue
            }
            guard item.isVisible else { continue }
            let title = localizedTitle(item: item, locale: locale)
            let artworkURL: URL?
            if let sourceURL = snapshot.content.assetURL(itemID: item.id, name: "artwork") {
                artworkURL = await assetCache.imageURL(
                    source: sourceURL,
                    contentVersion: snapshot.content.manifest.contentVersion,
                    itemID: item.id
                )
            } else {
                artworkURL = nil
            }
            let theme = Theme(
                id: base.id,
                titleKey: base.titleKey,
                collection: base.collection,
                artwork: base.artwork,
                isFree: item.accessPolicy == .free,
                symbol: base.symbol,
                appearance: base.appearance,
                interaction: base.interaction,
                titleOverride: title,
                artworkURL: artworkURL
            )
            themes.append((theme, item.order))
        }

        catalog = ThemeCatalog(themes: themes.sorted {
            if $0.order == $1.order { return $0.theme.id < $1.theme.id }
            return $0.order < $1.order
        }.map(\.theme))
        source = snapshot.source
    }

    private func localizedTitle(item: RemoteContentItem, locale: String) -> String? {
        let language = locale.split(separator: "-").first.map(String.init)
        return item.localizedText[locale]?["title"]
            ?? language.flatMap { item.localizedText[$0]?["title"] }
            ?? item.localizedText["en"]?["title"]
    }
}
