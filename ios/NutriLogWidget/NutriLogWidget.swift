import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), calories: 0, protein: 0, fat: 0, carbs: 0, water: "0.0 Л")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
    
    private func loadEntry() -> SimpleEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.nutrilog.app")
        let calories = userDefaults?.integer(forKey: "calories") ?? 0
        let protein = userDefaults?.integer(forKey: "proteins") ?? 0
        let fat = userDefaults?.integer(forKey: "fats") ?? 0
        let carbs = userDefaults?.integer(forKey: "carbs") ?? 0
        let water = userDefaults?.string(forKey: "water") ?? "0.0 Л"
        
        return SimpleEntry(
            date: Date(),
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
            water: water
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let calories: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    let water: String
}

struct NutriLogWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color(hex: "F5F8F7")
            
            if family == .systemMedium {
                // Medium Widget Layout
                HStack(spacing: 16) {
                    // Left Column (Calories)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("КАЛОРИИ")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "00C753"))
                        
                        Text("\(entry.calories)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(hex: "0F2317"))
                            
                        Text("осталось сегодня")
                            .font(.system(size: 10))
                            .foregroundColor(Color.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    // Right Column (Macros)
                    HStack(spacing: 16) {
                        MediumMacroView(label: "Белки", value: "\(entry.protein)г", color: Color(hex: "00C753"))
                        MediumMacroView(label: "Жиры", value: "\(entry.fat)г", color: Color(hex: "00C753"))
                        MediumMacroView(label: "Углев", value: "\(entry.carbs)г", color: Color(hex: "00C753"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
            } else {
                // Small Widget Layout
                VStack(spacing: 8) {
                    // Header
                    HStack {
                        Text("КАЛОРИИ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "00C753"))
                        Spacer()
                    }
                    
                    // Main Calories
                    HStack {
                        Text("\(entry.calories)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "0F2317"))
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Macros Row
                    HStack(spacing: 0) {
                        MacroView(label: "Б", value: entry.protein, color: Color(hex: "00C753"))
                        MacroView(label: "Ж", value: entry.fat, color: Color(hex: "00C753"))
                        MacroView(label: "У", value: entry.carbs, color: Color(hex: "00C753"))
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
                }
                .padding(12)
            }
        }
    }
}

struct MediumMacroView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "0F2317"))
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
        }
    }
}

struct MacroView: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "0F2317"))
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct NutriLogWidget: Widget {
    let kind: String = "NutriLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                NutriLogWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                NutriLogWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("NutriLog Дневник")
        .description("Ваши калории и БЖУ на сегодня.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NutriLogWaterWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color(hex: "F5F8F7")
            
            VStack(spacing: 8) {
                Text("ВОДА")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "00C753"))
                
                Text(entry.water)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "0F2317"))
            }
            .padding(12)
        }
    }
}

struct NutriLogWaterWidget: Widget {
    let kind: String = "NutriLogWaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                NutriLogWaterWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                NutriLogWaterWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("NutriLog Вода")
        .description("Ваш баланс воды на сегодня.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct NutriLogWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NutriLogWidget()
        NutriLogWaterWidget()
    }
}

// Helper for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
