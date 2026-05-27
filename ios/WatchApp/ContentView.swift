import SwiftUI
import WatchConnectivity

// Обертка для работы с WatchConnectivity (WCSession)
class WatchSessionManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchSessionManager()
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Активация завершена
    }
    
    // Метод для отправки данных на телефон
    func sendDataToPhone(action: String, value: Any) {
        guard WCSession.default.isReachable else {
            // Если телефон недоступен, пишем в UserDefaults и отправляем как UserInfo (дойдет при коннекте)
            let userInfo = ["action": action, "value": value]
            WCSession.default.transferUserInfo(userInfo)
            return
        }
        
        let message = ["action": action, "value": value]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Ошибка отправки сообщения: \(error.localizedDescription)")
        }
    }
}

struct ContentView: View {
    // Подключаем AppGroup хранилище UserDefaults для автоматического обновления UI
    private static let appGroup = "group.com.app.nutrilog.app.X4HMJXZ332"
    private static let sharedStore = UserDefaults(suiteName: appGroup)
    
    @AppStorage("calories", store: sharedStore) var calories: String = "0"
    @AppStorage("calorie_goal", store: sharedStore) var calorieGoal: String = "2000"
    
    @AppStorage("proteins_val", store: sharedStore) var proteins: String = "0"
    @AppStorage("protein_goal", store: sharedStore) var proteinGoal: String = "100"
    
    @AppStorage("fats_val", store: sharedStore) var fats: String = "0"
    @AppStorage("fat_goal", store: sharedStore) var fatGoal: String = "65"
    
    @AppStorage("carbs_val", store: sharedStore) var carbs: String = "0"
    @AppStorage("carbs_goal", store: sharedStore) var carbsGoal: String = "230"
    
    @AppStorage("water_value", store: sharedStore) var water: String = "0.0"
    @AppStorage("water_goal", store: sharedStore) var waterGoal: String = "2000"
    
    @AppStorage("steps", store: sharedStore) var steps: String = "0"
    @AppStorage("steps_goal", store: sharedStore) var stepsGoal: String = "10000"
    
    @AppStorage("weight_current", store: sharedStore) var weightCurrent: String = "70.0"
    @AppStorage("weight_goal", store: sharedStore) var weightGoal: String = "65.0"
    
    @State private var selectedTab = 0
    @State private var showingWeightPicker = false
    @State private var tempWeight: Double = 70.0
    @State private var showingRecipePicker = false
    
    // Быстрые рецепты-заглушки для логирования с часов
    let quickRecipes = [
        ("Куриное филе", 150),
        ("Яичница из 2 яиц", 180),
        ("Овсяная каша", 220),
        ("Творог с медом", 170),
        ("Яблоко с орехами", 120)
    ]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // ЭКРАН 1: СТАТИСТИКА
            ScrollView {
                VStack(spacing: 8) {
                    Text("СЕГОДНЯ")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(1.5)
                        .padding(.top, 4)
                    
                    // Прямоугольная премиальная карточка калорий
                    HStack(spacing: 8) {
                        // Кольцо прогресса слева
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 5)
                            Circle()
                                .trim(from: 0.0, to: CGFloat(min((Double(calories) ?? 0.0) / (Double(calorieGoal) ?? 2000.0), 1.0)))
                                .stroke(
                                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .rotationEffect(Angle(degrees: -90))
                            
                            VStack(spacing: 0) {
                                Text("\(Int(Double(calories) ?? 0.0))")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("ккал")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(width: 48, height: 48)
                        
                        // Детализация калорий справа
                        VStack(alignment: .leading, spacing: 2) {
                            DetailRow(label: "Цель:", value: "\(Int(Double(calorieGoal) ?? 2000.0)) ккал", color: .gray)
                            DetailRow(label: "Еда:", value: "-\(Int(Double(calories) ?? 0.0)) ккал", color: .red.opacity(0.8))
                            
                            let remaining = (Double(calorieGoal) ?? 2000.0) - (Double(calories) ?? 0.0)
                            DetailRow(
                                label: "Осталось:",
                                value: "\(Int(remaining)) ккал",
                                color: remaining >= 0 ? .green : .red,
                                isBold: true
                            )
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    
                    // Прогресс кольца БЖУ
                    HStack(spacing: 12) {
                        MacroCircle(label: "Б", val: proteins, goal: proteinGoal, color: .pink)
                        MacroCircle(label: "Ж", val: fats, goal: fatGoal, color: .yellow)
                        MacroCircle(label: "У", val: carbs, goal: carbsGoal, color: .cyan)
                    }
                    .padding(.vertical, 4)
                    
                    // Вода, вес, шаги
                    VStack(spacing: 4) {
                        StatTile(icon: "drop.fill", iconColor: .blue, title: "Вода", value: "\(Int((Double(water) ?? 0.0) * 1000.0)) мл", subtitle: "из \(waterGoal) мл")
                        Divider().background(Color.white.opacity(0.1))
                        StatTile(icon: "scalemass.fill", iconColor: .teal, title: "Вес", value: "\(weightCurrent) кг", subtitle: "цель \(weightGoal) кг")
                        Divider().background(Color.white.opacity(0.1))
                        StatTile(icon: "figure.walk", iconColor: .orange, title: "Шаги", value: steps, subtitle: "из \(stepsGoal)")
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 6)
            }
            .tag(0)
            
            // ЭКРАН 2: ВВОД ДАННЫХ
            ScrollView {
                VStack(spacing: 8) {
                    Text("БЫСТРЫЙ ВВОД")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(1.5)
                        .padding(.top, 4)
                    
                    // Кнопки Вода и Вес
                    HStack(spacing: 6) {
                        // Кнопка добавления воды
                        Button(action: {
                            addWaterDirectly()
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 16))
                                Text("+250 мл")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(LinearGradient(colors: [.blue.opacity(0.8), .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Кнопка изменения веса
                        Button(action: {
                            tempWeight = Double(weightCurrent) ?? 70.0
                            showingWeightPicker = true
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "scalemass.fill")
                                    .font(.system(size: 16))
                                Text("Вес")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(LinearGradient(colors: [.teal.opacity(0.8), .teal.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Text("БЫСТРЫЕ БЛЮДА")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                        .padding(.leading, 4)
                    
                    // Список популярных рецептов
                    VStack(spacing: 4) {
                        ForEach(quickRecipes, id: \.0) { recipe in
                            Button(action: {
                                showingRecipePicker = true
                                // Временный хак: сохраняем выбранный рецепт для лога
                                UserDefaults.standard.set(recipe.0, forKey: "selected_recipe_name")
                                UserDefaults.standard.set(recipe.1, forKey: "selected_recipe_calories")
                            }) {
                                HStack {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 10))
                                        .foregroundColor(.purple)
                                        .padding(6)
                                        .background(Color.purple.opacity(0.1))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(recipe.0)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("\(recipe.1) ккал")
                                            .font(.system(size: 8))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.purple)
                                }
                                .padding(6)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .tag(1)
        }
        // Диалог выбора веса
        .sheet(isPresented: $showingWeightPicker) {
            VStack(spacing: 8) {
                Text("ТЕКУЩИЙ ВЕС")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                
                HStack(spacing: 12) {
                    Button(action: { tempWeight = max(tempWeight - 0.1, 30.0) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.teal)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(String(format: "%.1f", tempWeight))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    
                    Button(action: { tempWeight = min(tempWeight + 0.1, 300.0) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.teal)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Text("кг")
                    .font(.system(size: 10))
                    .foregroundColor(.teal)
                
                HStack(spacing: 8) {
                    Button("Отмена") {
                        showingWeightPicker = false
                    }
                    .font(.system(size: 11))
                    
                    Button("Да") {
                        saveWeightDirectly(tempWeight)
                        showingWeightPicker = false
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.teal)
                }
                .padding(.top, 4)
            }
            .padding(10)
        }
        // Диалог выбора приема пищи для рецепта
        .sheet(isPresented: $showingRecipePicker) {
            VStack(spacing: 6) {
                Text("ДОБАВИТЬ В...")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(.bottom, 2)
                
                ScrollView {
                    VStack(spacing: 4) {
                        MealTypeButton(label: "Завтрак", key: "breakfast", icon: "coffee", color: .orange) { logRecipe("breakfast") }
                        MealTypeButton(label: "Обед", key: "lunch", icon: "fork.knife", color: .red) { logRecipe("lunch") }
                        MealTypeButton(label: "Ужин", key: "dinner", icon: "sparkles", color: .purple) { logRecipe("dinner") }
                        MealTypeButton(label: "Перекусы", key: "snacks", icon: "apple", color: .green) { logRecipe("snacks") }
                    }
                }
            }
            .padding(8)
        }
    }
    
    // --- Локальные и сетевые операции ---
    
    private func addWaterDirectly() {
        let currentWater = Double(water) ?? 0.0
        let newWater = currentWater + 0.250
        water = String(format: "%.2f", newWater) // Мгновенное обновление UI на часах
        
        // Отправка транзакции на телефон
        WatchSessionManager.shared.sendDataToPhone(action: "addWater", value: 250)
    }
    
    private func saveWeightDirectly(_ val: Double) {
        weightCurrent = String(format: "%.1f", val) // Мгновенное обновление UI на часах
        
        // Отправка на телефон
        WatchSessionManager.shared.sendDataToPhone(action: "updateWeight", value: val)
    }
    
    private func logRecipe(_ mealKey: String) {
        showingRecipePicker = false
        let name = UserDefaults.standard.string(forKey: "selected_recipe_name") ?? ""
        let caloriesVal = UserDefaults.standard.integer(forKey: "selected_recipe_calories")
        
        // Мгновенно обновляем локально съеденные калории в UI на часах
        let currentCal = Double(calories) ?? 0.0
        calories = String(currentCal + Double(caloriesVal))
        
        // Отправка транзакции добавления рецепта на телефон
        WatchSessionManager.shared.sendDataToPhone(action: "addRecipe", value: [
            "meal": mealKey,
            "name": name,
            "calories": caloriesVal
        ])
    }
}

// Вспомогательные нативные вью
struct DetailRow: View {
    let label: String
    let value: String
    let color: Color
    var isBold = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 8, weight: isBold ? .bold : .regular))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: isBold ? .bold : .semibold))
                .foregroundColor(color)
        }
    }
}

struct MacroCircle: View {
    let label: String
    let val: String
    let goal: String
    let color: Color
    
    var body: some View {
        let current = Double(val) ?? 0.0
        let target = Double(goal) ?? 100.0
        let ratio = target > 0 ? current / target : 0.0
        
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 3)
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(ratio, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(Angle(degrees: -90))
                
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 28, height: 28)
            
            Text("\(Int(current))г")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
            Text("/\(Int(target))г")
                .font(.system(size: 6))
                .foregroundColor(.gray)
        }
    }
}

struct StatTile: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.gray)
                Text(subtitle)
                    .font(.system(size: 6))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 1)
    }
}

struct MealTypeButton: View {
    let label: String
    let key: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
            .padding(6)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
