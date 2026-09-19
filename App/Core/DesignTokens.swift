import SwiftUI

enum Design {
    static let background = Color(red: 0.035, green: 0.045, blue: 0.055)
    static let surface = Color(red: 0.085, green: 0.095, blue: 0.11)
    static let accent = Color(red: 0.76, green: 0.98, blue: 0.42)
    static let muted = Color(red: 0.60, green: 0.64, blue: 0.66)
    static let radius: CGFloat = 26
    static let padding: CGFloat = 22
    static let gap: CGFloat = 16
    static func tint(_ collection: ThemeCollection) -> Color {
        switch collection { case .vehicles: Color(red: 1, green: 0.66, blue: 0.39); case .ocean: .cyan; case .cosmos: .purple; case .nature: accent }
    }
}

func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

struct PrimaryButton: View {
    let title: String
    var symbol = "arrow.right"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(LocalizedStringKey(title)).font(.headline); Spacer(); Image(systemName: symbol) }
                .padding(18).frame(minHeight: 56).foregroundStyle(.black)
                .background(Design.accent, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}
