import SwiftUI

enum InstallKind: String, CaseIterable, Identifiable {
    case wallpaper, icons, widgets
    var id: String { rawValue }
    var steps: [String] { (1...3).map { "install.\(rawValue).\($0)" } }
    var symbols: [String] {
        switch self { case .wallpaper: ["photo.on.rectangle", "lock.rectangle", "checkmark.rectangle"]; case .icons: ["square.and.arrow.down", "arrow.triangle.branch", "plus.app"]; case .widgets: ["hand.tap", "plus.circle", "square.grid.2x2"] }
    }
}
struct InstallView: View {
    let kind: InstallKind
    @Environment(LibraryStore.self) private var library
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("install.intro").font(.title2.bold())
                Text("install.manual").foregroundStyle(Design.muted)
                ForEach(Array(kind.steps.enumerated()), id: \.element) { index, key in
                    Button { library.toggleStep(key) } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack { Image(systemName: kind.symbols[index]).font(.system(size: 32)).foregroundStyle(Design.accent); Spacer(); Image(systemName: library.installationSteps.contains(key) ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(library.installationSteps.contains(key) ? Design.accent : Design.muted) }
                            Text(LocalizedStringKey(key)).font(.body).multilineTextAlignment(.leading)
                            Text(library.installationSteps.contains(key) ? "install.completed" : "install.mark").font(.caption).foregroundStyle(Design.muted)
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Design.surface, in: RoundedRectangle(cornerRadius: 24))
                    }.buttonStyle(.plain)
                }
                if kind == .wallpaper { Text("platform.detail").font(.footnote).foregroundStyle(Design.muted) }
            }.padding(Design.padding)
        }.background(Design.background).navigationTitle(LocalizedStringKey("install." + kind.rawValue)).navigationBarTitleDisplayMode(.inline)
    }
}
