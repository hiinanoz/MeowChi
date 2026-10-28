import SwiftUI
import WidgetKit

/// Home-screen widget: the cat's picture and needs, from the forecast the app writes.
struct CatEntry: TimelineEntry {
    let date: Date
    let name: String
    let point: WidgetSnapshot.Point?
    let image: UIImage?
}

struct CatProvider: TimelineProvider {
    static let empty = CatEntry(date: .now, name: "Meowchi", point: nil, image: nil)

    func placeholder(in context: Context) -> CatEntry { Self.empty }

    func getSnapshot(in context: Context, completion: @escaping (CatEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CatEntry>) -> Void) {
        guard let loaded = WidgetSnapshot.load() else {
            return completion(Timeline(entries: [Self.empty], policy: .after(.now.addingTimeInterval(3600))))
        }
        let entries = loaded.snapshot.points.filter { $0.date >= .now.addingTimeInterval(-3600) }.map {
            CatEntry(date: $0.date, name: loaded.snapshot.name, point: $0, image: loaded.image)
        }
        completion(Timeline(entries: entries.isEmpty ? [entry(at: .now)] : entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> CatEntry {
        guard let loaded = WidgetSnapshot.load() else { return Self.empty }
        return CatEntry(date: date, name: loaded.snapshot.name, point: loaded.snapshot.point(at: date), image: loaded.image)
    }
}

private enum WidgetPalette {
    static let ink = Color(red: 0.23, green: 0.15, blue: 0.16)
    static let panel = Color(red: 1.0, green: 0.95, blue: 0.88)
    static let track = Color(red: 0.78, green: 0.70, blue: 0.64)

    static func level(_ value: Double) -> Color {
        value >= 60 ? Color(red: 0.42, green: 0.78, blue: 0.40) : value >= 30 ? Color(red: 0.98, green: 0.75, blue: 0.25)
            : Color(red: 0.92, green: 0.33, blue: 0.33)
    }
}

struct CatWidgetView: View {
    let entry: CatEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 4) {
                catImage
                Text(verbatim: entry.name).font(.system(size: 13, weight: .heavy, design: .monospaced)).lineLimit(1)
            }
            if family == .systemMedium {
                if let point = entry.point {
                    VStack(alignment: .leading, spacing: 5) {
                        bar("icon_hunger", point.hunger)
                        bar("icon_energy", point.energy)
                        bar("icon_happiness", point.happiness)
                        bar("icon_cleanliness", point.cleanliness)
                        bar("icon_health", point.health)
                    }
                } else {
                    Text("widget.open").font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
        }
        .foregroundStyle(WidgetPalette.ink)
        .containerBackground(WidgetPalette.panel, for: .widget)
    }

    @ViewBuilder private var catImage: some View {
        if let image = entry.image {
            Image(uiImage: image).interpolation(.none).resizable().frame(width: 96, height: 96)
                .overlay(alignment: .topTrailing) { needBadge }
        } else {
            Image("icon_happiness").interpolation(.none).resizable().frame(width: 48, height: 48)
        }
    }

    /// Small-widget hint: icon of the need that most wants attention, when it is getting low.
    @ViewBuilder private var needBadge: some View {
        if family == .systemSmall, let point = entry.point, min(point.hunger, point.energy, point.happiness, point.cleanliness) < 40 {
            Image("icon_" + point.lowestNeed).interpolation(.none).resizable().frame(width: 22, height: 22)
                .padding(3).background(Circle().fill(.white))
        }
    }

    private func bar(_ icon: String, _ value: Double) -> some View {
        HStack(spacing: 6) {
            Image(icon).interpolation(.none).resizable().frame(width: 14, height: 14)
            ZStack(alignment: .leading) {
                Rectangle().fill(WidgetPalette.track)
                Rectangle().fill(WidgetPalette.level(value)).frame(width: 110 * value / 100)
            }
            .frame(width: 110, height: 8)
            .overlay(Rectangle().stroke(WidgetPalette.ink, lineWidth: 1.5))
        }
    }
}

struct MeowchiCatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MeowchiCat", provider: CatProvider()) { entry in
            CatWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.name")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct MeowchiWidgetBundle: WidgetBundle {
    var body: some Widget { MeowchiCatWidget() }
}
