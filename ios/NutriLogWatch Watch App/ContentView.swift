//
//  ContentView.swift
//  NutriLogWatch Watch App
//
//  Created by Александр Рыженков on 28.05.2026.
//

import SwiftUI
import WatchConnectivity

// MARK: - Connectivity Manager
class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var caloriesConsumed: Int = 1450
    @Published var caloriesTarget: Int = 2000
    
    @Published var proteinsConsumed: Double = 85.0
    @Published var proteinsTarget: Double = 130.0
    
    @Published var fatsConsumed: Double = 45.0
    @Published var fatsTarget: Double = 70.0
    
    @Published var carbsConsumed: Double = 160.0
    @Published var carbsTarget: Double = 220.0
    
    @Published var waterConsumed: Double = 1.25 // In Liters
    @Published var waterTarget: Double = 2.5
    
    @Published var weightCurrent: Double = 74.5
    @Published var weightTarget: Double = 70.0
    @Published var weightStart: Double = 78.0
    
    private var session: WCSession?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        loadLocalData()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Activated
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let calCons = message["caloriesConsumed"] as? Int { self.caloriesConsumed = calCons }
            if let calTarget = message["caloriesTarget"] as? Int { self.caloriesTarget = calTarget }
            
            if let protCons = message["proteinsConsumed"] as? Double { self.proteinsConsumed = protCons }
            if let protTarget = message["proteinsTarget"] as? Double { self.proteinsTarget = protTarget }
            
            if let fCons = message["fatsConsumed"] as? Double { self.fatsConsumed = fCons }
            if let fTarget = message["fatsTarget"] as? Double { self.fatsTarget = fTarget }
            
            if let cCons = message["carbsConsumed"] as? Double { self.carbsConsumed = cCons }
            if let cTarget = message["carbsTarget"] as? Double { self.carbsTarget = cTarget }
            
            if let wCons = message["waterConsumed"] as? Double { self.waterConsumed = wCons }
            if let wTarget = message["waterTarget"] as? Double { self.waterTarget = wTarget }
            
            if let wCurr = message["weightCurrent"] as? Double { self.weightCurrent = wCurr }
            if let wTarg = message["weightTarget"] as? Double { self.weightTarget = wTarg }
            if let wStart = message["weightStart"] as? Double { self.weightStart = wStart }
            
            self.saveLocalData()
        }
    }
    
    func addWater(ml: Double) {
        waterConsumed = min(waterTarget * 2.0, max(0.0, waterConsumed + (ml / 1000.0)))
        saveLocalData()
        sendWaterToPhone(ml: ml)
    }
    
    private func sendWaterToPhone(ml: Double) {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(["addWaterMl": ml, "totalWaterLiters": waterConsumed], replyHandler: nil, errorHandler: nil)
    }
    
    private func saveLocalData() {
        let defaults = UserDefaults.standard
        defaults.set(caloriesConsumed, forKey: "calCons")
        defaults.set(caloriesTarget, forKey: "calTarget")
        defaults.set(proteinsConsumed, forKey: "protCons")
        defaults.set(proteinsTarget, forKey: "protTarget")
        defaults.set(fatsConsumed, forKey: "fatsCons")
        defaults.set(fatsTarget, forKey: "fatsTarget")
        defaults.set(carbsConsumed, forKey: "carbsCons")
        defaults.set(carbsTarget, forKey: "carbsTarget")
        defaults.set(waterConsumed, forKey: "waterCons")
        defaults.set(waterTarget, forKey: "waterTarget")
        defaults.set(weightCurrent, forKey: "weightCurrent")
        defaults.set(weightTarget, forKey: "weightTarget")
        defaults.set(weightStart, forKey: "weightStart")
    }
    
    private func loadLocalData() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "calTarget") != nil {
            caloriesConsumed = defaults.integer(forKey: "calCons")
            caloriesTarget = defaults.integer(forKey: "calTarget")
            proteinsConsumed = defaults.double(forKey: "protCons")
            proteinsTarget = defaults.double(forKey: "protTarget")
            fatsConsumed = defaults.double(forKey: "fatsCons")
            fatsTarget = defaults.double(forKey: "fatsTarget")
            carbsConsumed = defaults.double(forKey: "carbsCons")
            carbsTarget = defaults.double(forKey: "carbsTarget")
            waterConsumed = defaults.double(forKey: "waterCons")
            waterTarget = defaults.double(forKey: "waterTarget")
            weightCurrent = defaults.double(forKey: "weightCurrent")
            weightTarget = defaults.double(forKey: "weightTarget")
            weightStart = defaults.double(forKey: "weightStart")
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var vm = WatchViewModel()
    
    var body: some View {
        TabView {
            // Page 1: Diary / Food Progress
            DiaryView(vm: vm)
                .tag(0)
            
            // Page 2: Analytics / Goals
            AnalyticsView(vm: vm)
                .tag(1)
            
            // Page 3: Quick Add Water
            QuickWaterView(vm: vm)
                .tag(2)
        }
        .tabViewStyle(.page)
        .accentColor(Color(red: 0.11, green: 0.73, blue: 0.33))
    }
}

// MARK: - Subviews
struct DiaryView: View {
    @ObservedObject var vm: WatchViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "fork.knife.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    Text("Дневник")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                // Circular Progress for Calories
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 10)
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(1.0, Double(vm.caloriesConsumed) / max(1.0, Double(vm.caloriesTarget)))))
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(red: 0.11, green: 0.73, blue: 0.33), .emerald]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: -90))
                        .frame(width: 90, height: 90)
                        .animation(.easeOut, value: vm.caloriesConsumed)
                    
                    VStack {
                        Text("\(vm.caloriesTarget - vm.caloriesConsumed)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("осталось")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 4)
                
                // Macro details
                VStack(spacing: 6) {
                    MacroBar(label: "Белки", consumed: vm.proteinsConsumed, target: vm.proteinsTarget, color: .orange)
                    MacroBar(label: "Жиры", consumed: vm.fatsConsumed, target: vm.fatsTarget, color: .blue)
                    MacroBar(label: "Углеводы", consumed: vm.carbsConsumed, target: vm.carbsTarget, color: .customCyan)
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 10)
        }
    }
}

struct MacroBar: View {
    let label: String
    let consumed: Double
    let target: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(consumed))/\(Int(target)) г")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: CGFloat(min(1.0, consumed / max(1.0, target))) * geometry.size.width, height: 5)
                }
            }
            .frame(height: 5)
        }
    }
}

struct AnalyticsView: View {
    @ObservedObject var vm: WatchViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.xaxis.ascending")
                        .foregroundColor(.orange)
                        .font(.title3)
                    Text("Цели")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                // Weight Goal
                VStack(spacing: 4) {
                    HStack {
                        Text("Вес:")
                            .font(.system(size: 12, weight: .medium))
                        Text(String(format: "%.1f кг", vm.weightCurrent))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Spacer()
                    }
                    
                    // Weight Progress Bar
                    let totalChange = vm.weightStart - vm.weightTarget
                    let currentChange = vm.weightStart - vm.weightCurrent
                    let progress = totalChange != 0 ? max(0.0, min(1.0, currentChange / totalChange)) : 1.0
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(gradient: Gradient(colors: [.green, .emerald]), startPoint: .leading, endPoint: .trailing))
                                .frame(width: CGFloat(progress) * geo.size.width, height: 6)
                        }
                    }
                    .frame(height: 6)
                    
                    HStack {
                        Text(String(format: "Старт: %.1f", vm.weightStart))
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                        Spacer()
                        Text(String(format: "Цель: %.1f", vm.weightTarget))
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                // Calorie Target Card
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Калории")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(vm.caloriesTarget) ккал")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    Text(vm.caloriesConsumed > vm.caloriesTarget ? "Лимит превышен!" : "Норма соблюдается")
                        .font(.system(size: 10))
                        .foregroundColor(vm.caloriesConsumed > vm.caloriesTarget ? .red : .gray)
                }
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }
}

struct QuickWaterView: View {
    @ObservedObject var vm: WatchViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                Text("Вода")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(String(format: "%.2f л", vm.waterConsumed))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 4)
            
            // Visual Cup Container
            ZStack(alignment: .bottom) {
                // Cup Outline
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                    .frame(width: 50, height: 60)
                
                // Filled Water Level
                let fillPercent = min(1.0, vm.waterConsumed / max(1.0, vm.waterTarget))
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue.opacity(0.8), Color(red: 0.1, green: 0.5, blue: 0.9)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 46, height: CGFloat(fillPercent * 56))
                    .padding(.bottom, 2)
                    .animation(.spring(), value: vm.waterConsumed)
                
                Text(String(format: "%.0f%%", fillPercent * 100))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .offset(y: -20)
            }
            .frame(height: 60)
            
            // Quick Add Buttons
            HStack(spacing: 8) {
                Button(action: {
                    vm.addWater(ml: 250)
                }) {
                    VStack {
                        Text("+250")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text("мл")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    vm.addWater(ml: 500)
                }) {
                    VStack {
                        Text("+500")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text("мл")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.blue.opacity(0.5))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 38)
        }
    }
}

// Extensions for convenient color usage
extension Color {
    static let customCyan = Color(red: 0.2, green: 0.8, blue: 0.9)
    static let emerald = Color(red: 0.05, green: 0.65, blue: 0.3)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
