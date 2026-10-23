import SwiftUI
import WidgetKit
import AppIntents

private enum WidgetPalette {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.09)
    static func accent(_ collection: String) -> Color {
        switch collection {
        case "vehicles": Color(red: 1, green: 0.64, blue: 0.36)
        case "cosmos": Color(red: 0.75, green: 0.64, blue: 1)
        case "nature": Color(red: 0.66, green: 0.86, blue: 0.65)
        default: Color(red: 0.45, green: 0.88, blue: 0.9)
        }
    }
}

enum MotionWidgetStyle: String, AppEnum {
    case photo, date, calendar, collection
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "widget.style"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .photo: "widget.photo", .date: "widget.date", .calendar: "widget.calendar", .collection: "widget.collection"
    ]
}

struct MotionWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.configuration"
    static let description = IntentDescription("widget.configuration.description")
    @Parameter(title: "widget.style", default: .photo) var style: MotionWidgetStyle
}

/// The widget answers a tap in place: the scene steps to the next time of day and plays its collection's effect.
struct AdvanceSceneIntent: AppIntent {
    static let title: LocalizedStringResource = "widget.tap"
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult {
        WidgetScenePhase.advance()
        return .result()
    }
}

struct MotionEntry: TimelineEntry {
    let date: Date
    let configuration: MotionWidgetIntent
    let snapshot: WidgetSnapshot
}

struct MotionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MotionEntry {
        .init(date: .now, configuration: MotionWidgetIntent(), snapshot: .placeholder)
    }
    func snapshot(for configuration: MotionWidgetIntent, in context: Context) async -> MotionEntry {
        .init(date: .now, configuration: configuration, snapshot: .read())
    }
    func timeline(for configuration: MotionWidgetIntent, in context: Context) async -> Timeline<MotionEntry> {
        let now = Date()
        let snapshot = WidgetSnapshot.read()
        let minute = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
        let entries = (0..<60).map { offset in
            MotionEntry(date: minute.addingTimeInterval(Double(offset) * 60), configuration: configuration, snapshot: snapshot)
        }
        return Timeline(entries: entries, policy: .after(minute.addingTimeInterval(3600)))
    }
}

struct MotionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MotionEntry
    private var accent: Color { WidgetPalette.accent(entry.snapshot.collection) }
    var body: some View {
        Group {
            if family == .accessoryCircular {
                VStack(spacing: 2) {
                    Image(systemName: "sparkles")
                    Text(entry.date, format: .dateTime.day()).font(.headline)
                }
            } else if family == .accessoryRectangular {
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey(entry.snapshot.titleKey)).font(.headline)
                    Text(entry.date, format: .dateTime.weekday().month().day())
                }
            } else {
                content
            }
        }
        .containerBackground(for: .widget) { background }
        .widgetURL(entry.snapshot.deepLink)
    }
    @ViewBuilder private var content: some View {
        switch entry.configuration.style {
        case .photo:
            Button(intent: AdvanceSceneIntent()) {
                ZStack {
                    SceneEffect(collection: entry.snapshot.collection, phase: WidgetScenePhase.current, seed: WidgetScenePhase.taps)
                    VStack { Spacer(); HStack { Text(LocalizedStringKey(entry.snapshot.titleKey)).font(.headline); Spacer(); Image(systemName: "hand.tap").font(.caption) } }
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .date:
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.date, format: .dateTime.weekday(.wide)).font(.caption).textCase(.uppercase).foregroundStyle(accent)
                Text(entry.date, style: .time).font(.system(.largeTitle, design: .rounded, weight: .light)).minimumScaleFactor(0.7)
                Text(entry.date, format: .dateTime.month(.wide).day()).font(.subheadline)
            }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white)
        case .calendar: calendar
        case .collection:
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "square.stack.3d.up").font(.largeTitle).foregroundStyle(accent)
                Spacer(minLength: 0)
                Text(LocalizedStringKey("collection." + entry.snapshot.collection)).font(.headline)
                Text("widget.open").font(.caption).foregroundStyle(accent)
            }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.white)
        }
    }
    private var calendar: some View {
        let calendar = Calendar.current
        let days = calendar.range(of: .day, in: .month, for: entry.date) ?? 1..<29
        let start = calendar.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let today = calendar.component(.day, from: entry.date)
        return VStack(alignment: .leading, spacing: 6) {
            Text(entry.date, format: .dateTime.month(.wide)).font(.caption.bold()).foregroundStyle(accent)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
                ForEach(0..<(days.count + offset), id: \.self) { cell in
                    let day = cell - offset + 1
                    Text(cell < offset ? "" : day.formatted())
                        .font(.system(size: 10, weight: day == today ? .bold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 13)
                        .foregroundStyle(day == today ? WidgetPalette.background : .white)
                        .background(day == today ? accent : .clear, in: Circle())
                }
            }
        }
    }
    @ViewBuilder private var background: some View {
        if entry.configuration.style == .photo, let url = entry.snapshot.artworkURL,
           let image = UIImage(contentsOfFile: url.path) {
            GeometryReader { proxy in
                Image(uiImage: image).resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped()
                    .overlay(WidgetScenePhase.current.tint)
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom))
            }
        } else {
            Rectangle().fill(WidgetPalette.background.gradient)
        }
    }
}

extension WidgetScenePhase {
    var tint: some View {
        switch self {
        case .day: LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
        case .dusk: LinearGradient(colors: [Color(red: 1, green: 0.45, blue: 0.2).opacity(0.38), Color(red: 0.5, green: 0.15, blue: 0.4).opacity(0.3)], startPoint: .top, endPoint: .bottom)
        case .night: LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.2).opacity(0.62), Color(red: 0.02, green: 0.02, blue: 0.08).opacity(0.5)], startPoint: .top, endPoint: .bottom)
        }
    }
}

/// Deterministic per-tap effect: headlight flares, bubbles, shooting stars or fireflies.
private struct SceneEffect: View {
    let collection: String
    let phase: WidgetScenePhase
    let seed: Int

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                switch collection {
                case "vehicles":
                    ForEach(0..<2, id: \.self) { index in
                        Circle().fill(RadialGradient(colors: [.white, Color(red: 1, green: 0.85, blue: 0.55).opacity(0.6), .clear], center: .center, startRadius: 1, endRadius: 22))
                            .frame(width: 44, height: 44)
                            .position(x: size.width * (0.42 + Double(index) * 0.16), y: size.height * 0.62)
                    }
                case "cosmos":
                    Capsule().fill(LinearGradient(colors: [.clear, .white], startPoint: .leading, endPoint: .trailing))
                        .frame(width: size.width * 0.45, height: 2)
                        .rotationEffect(.degrees(-24))
                        .position(x: size.width * unit(1), y: size.height * (0.2 + unit(2) * 0.25))
                default:
                    ForEach(0..<7, id: \.self) { index in
                        let bubble = collection == "ocean"
                        Circle()
                            .fill(bubble ? Color.white.opacity(0.08) : Color(red: 0.95, green: 1, blue: 0.5).opacity(0.9))
                            .overlay(Circle().stroke(bubble ? Color.white.opacity(0.7) : .clear, lineWidth: 1))
                            .shadow(color: bubble ? .clear : Color(red: 0.9, green: 1, blue: 0.4), radius: 5)
                            .frame(width: bubble ? 6 + unit(index * 3) * 10 : 4, height: bubble ? 6 + unit(index * 3) * 10 : 4)
                            .position(x: size.width * unit(index * 5 + 1), y: size.height * (0.15 + unit(index * 7 + 2) * 0.6))
                    }
                }
            }
            .opacity(phase == .day && collection != "vehicles" ? 0.75 : 1)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .id(seed)
        .allowsHitTesting(false)
    }

    /// A stable pseudo-random value in 0...1 for this tap, so the widget never flickers on reload.
    private func unit(_ salt: Int) -> Double {
        var value = UInt64(truncatingIfNeeded: (seed &* 7919) &+ salt &* 104_729 &+ 13)
        value = (value ^ (value >> 13)) &* 0x5bd1e995
        return Double(value % 1000) / 1000
    }
}

@main
struct ScreenMotionWidget: Widget {
    let kind = "ScreenMotionWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MotionWidgetIntent.self, provider: MotionProvider()) { entry in
            MotionWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.name")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
