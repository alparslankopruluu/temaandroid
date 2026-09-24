import SwiftUI

struct InstallView: View {
    let kind: InstallKind
    let theme: Theme?
    let configuration: SceneConfiguration
    @Environment(LibraryStore.self) private var library
    init(kind: InstallKind, theme: Theme? = nil, configuration: SceneConfiguration = .init()) {
        self.kind = kind
        self.theme = theme
        self.configuration = configuration
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("install.intro").font(.title2.bold())
                Text("install.manual").foregroundStyle(Design.muted)
                ForEach(Array(kind.steps.enumerated()), id: \.element) { index, key in
                    let completed = theme.map { library.installationProgress(themeID: $0.id, configuration: configuration).completedSteps.contains("\(kind.rawValue).\(index + 1)") } ?? library.installationSteps.contains(key)
                    Button {
                        if let theme { library.toggleInstallationStep(index + 1, kind: kind, themeID: theme.id, configuration: configuration) }
                        else { library.toggleStep(key) }
                    } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack { Image(systemName: kind.symbols[index]).font(.system(size: 32)).foregroundStyle(Design.accent); Spacer(); Image(systemName: completed ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(completed ? Design.accent : Design.muted) }
                            Text(LocalizedStringKey(key)).font(.body).multilineTextAlignment(.leading)
                            Text(completed ? "install.completed" : "install.mark").font(.caption).foregroundStyle(Design.muted)
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Design.surface, in: RoundedRectangle(cornerRadius: 24))
                    }.buttonStyle(.plain)
                }
                if kind == .wallpaper { Text("platform.detail").font(.footnote).foregroundStyle(Design.muted) }
            }.padding(Design.padding)
        }.background(Design.background).navigationTitle(LocalizedStringKey("install." + kind.rawValue)).navigationBarTitleDisplayMode(.inline)
    }
}
