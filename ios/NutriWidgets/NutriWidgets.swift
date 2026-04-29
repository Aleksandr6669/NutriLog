import WidgetKit
import SwiftUI

private let appGroupId = "group.com.nutrilog.app.nutrilog"

struct NutriEntry: TimelineEntry {
    let date: Date
    let caloriesConsumed: Int
    let caloriesGoal: Int
    let caloriesRemaining: Int
    let protein: Int
    let proteinGoal: Int
    let fat: Int
    let fatGoal: Int
    let carbs: Int
    let carbsGoal: Int
    let waterLiters: String
    let waterGoalLiters: String
    let waterIntake: Int
    let waterGoal: Int
}

struct NutriProvider: TimelineProvider {
    func placeholder(in context: Context) -> NutriEntry {
        NutriEntry(
            date: Date(),
            caloriesConsumed: 1500,
            caloriesGoal: 1800,
            caloriesRemaining: 300,
            protein: 90,
            proteinGoal: 120,
            fat: 45,
            fatGoal: 60,
            carbs: 170,
            carbsGoal: 195,
            waterLiters: "1.4",
            waterGoalLiters: "2.0",
            waterIntake: 1400,
            waterGoal: 2000
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NutriEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutriEntry>) -> Void) {
        let entry = loadEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadEntry() -> NutriEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        return NutriEntry(
            date: Date(),
            caloriesConsumed: defaults?.integer(forKey: "widget_calories_consumed") ?? 0,
            caloriesGoal: defaults?.integer(forKey: "widget_calories_goal") ?? 0,
            caloriesRemaining: defaults?.integer(forKey: "widget_calories_remaining") ?? 0,
            protein: defaults?.integer(forKey: "widget_protein") ?? 0,
            proteinGoal: defaults?.integer(forKey: "widget_protein_goal") ?? 0,
            fat: defaults?.integer(forKey: "widget_fat") ?? 0,
            fatGoal: defaults?.integer(forKey: "widget_fat_goal") ?? 0,
            carbs: defaults?.integer(forKey: "widget_carbs") ?? 0,
            carbsGoal: defaults?.integer(forKey: "widget_carbs_goal") ?? 0,
            waterLiters: defaults?.string(forKey: "widget_water_liters") ?? "0.0",
            waterGoalLiters: defaults?.string(forKey: "widget_water_goal_liters") ?? "0.0",
            waterIntake: defaults?.integer(forKey: "widget_water_intake") ?? 0,
            waterGoal: defaults?.integer(forKey: "widget_water_goal") ?? 0
        )
    }
}

private struct WidgetCard: View {
    let title: String
    @ViewBuilder var content: some View

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.96, green: 0.99, blue: 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.13, green: 0.63, blue: 0.42).opacity(0.2), lineWidth: 1)
        )
    }
}

struct NutriSmallWidgetView: View {
    var entry: NutriEntry

    var body: some View {
        WidgetCard(title: "Дневная цель") {
            Text("\(entry.caloriesRemaining)")
                .font(.system(size: 30, weight: .bold))
            Text("Осталось ккал")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct NutriMediumWidgetView: View {
    var entry: NutriEntry

    var body: some View {
        WidgetCard(title: "NutriLog") {
            Text("\(entry.caloriesConsumed) / \(entry.caloriesGoal) ккал")
                .font(.headline)
            Text("Б \(entry.protein)/\(entry.proteinGoal)   Ж \(entry.fat)/\(entry.fatGoal)   У \(entry.carbs)/\(entry.carbsGoal)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct NutriLargeWidgetView: View {
    var entry: NutriEntry

    var body: some View {
        WidgetCard(title: "Дневные цели") {
            Text("\(entry.caloriesRemaining) ккал")
                .font(.system(size: 28, weight: .bold))
            Text("Съедено: \(entry.caloriesConsumed) / \(entry.caloriesGoal)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Text("Белки: \(entry.protein)/\(entry.proteinGoal) г")
                .font(.caption)
            Text("Жиры: \(entry.fat)/\(entry.fatGoal) г")
                .font(.caption)
            Text("Углеводы: \(entry.carbs)/\(entry.carbsGoal) г")
                .font(.caption)
            Divider()
            Text("Вода: \(entry.waterLiters) / \(entry.waterGoalLiters) л")
                .font(.caption)
                .foregroundStyle(Color.blue)
        }
    }
}

struct NutriWaterWidgetView: View {
    var entry: NutriEntry

    var body: some View {
        WidgetCard(title: "Вода") {
            Text("\(entry.waterLiters) / \(entry.waterGoalLiters) л")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.blue)
            Text("\(entry.waterIntake) из \(entry.waterGoal) мл")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct NutriSmallWidget: Widget {
    let kind: String = "NutriSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutriProvider()) { entry in
            NutriSmallWidgetView(entry: entry)
        }
        .configurationDisplayName("NutriLog Small")
        .description("Калории и остаток")
        .supportedFamilies([.systemSmall])
    }
}

struct NutriMediumWidget: Widget {
    let kind: String = "NutriMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutriProvider()) { entry in
            NutriMediumWidgetView(entry: entry)
        }
        .configurationDisplayName("NutriLog Medium")
        .description("Калории и БЖУ")
        .supportedFamilies([.systemMedium])
    }
}

struct NutriLargeWidget: Widget {
    let kind: String = "NutriLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutriProvider()) { entry in
            NutriLargeWidgetView(entry: entry)
        }
        .configurationDisplayName("NutriLog Large")
        .description("Дневные цели, БЖУ и вода")
        .supportedFamilies([.systemLarge])
    }
}

struct NutriWaterWidget: Widget {
    let kind: String = "NutriWaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutriProvider()) { entry in
            NutriWaterWidgetView(entry: entry)
        }
        .configurationDisplayName("NutriLog Water")
        .description("Отдельный виджет воды")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct NutriWidgetBundle: WidgetBundle {
    var body: some Widget {
        NutriSmallWidget()
        NutriMediumWidget()
        NutriLargeWidget()
        NutriWaterWidget()
    }
}
