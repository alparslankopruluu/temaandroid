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
            VStack { Spacer(); HStack { Text(LocalizedStringKey(entry.snapshot.titleKey)).font(.headline); Spacer() } }
                .foregroundStyle(.white)
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
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom))
            }
        } else {
            Rectangle().fill(WidgetPalette.background.gradient)
        }
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
