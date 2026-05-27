# Руководство: Создание виджетов для смарт-часов в Flutter (Apple Watch & Wear OS)

В данном руководстве подробно описано, как создать и настроить виджеты (Complications/Tiles) для смарт-часов (**Apple Watch / watchOS** и **Android / Wear OS**), синхронизированные с данными вашего Flutter-приложения.

---

## Часть 1: Архитектурный подход

Поскольку смарт-часы имеют жесткие ограничения по энергопотреблению и производительности, запускать полноценный движок Flutter прямо в фоне на часах для обновления циферблата не рекомендуется. 

Вместо этого используется **нативный гибридный подход**:
1. **Основное Flutter-приложение** сохраняет текущие метрики (калории, БЖУ, шаги, воду) в защищенное общее хранилище устройства.
2. **Нативная часть часов** (SwiftUI на iOS и Kotlin на Android) считывает эти данные и мгновенно отображает их в виджетах (Complications/Tiles), расходуя минимум батареи.
3. Данные синхронизируются через **App Groups (iOS)** и **Wearable Data Client / SharedPreferences (Android)**.

---

## Часть 2: Настройка виджета для Apple Watch (watchOS)

### 1. Добавление Watch Target в Xcode
1. Откройте ваш проект в Xcode (`ios/Runner.xcworkspace`).
2. Перейдите в **File > New > Target...**
3. Выберите **watchOS** -> **App** или **Widget Extension** (для виджетов на циферблате).
4. Укажите название (например, `NutriLogWatchWidget`) и нажмите **Finish**.
5. Xcode спросит о создании новой схемы активации — нажмите **Activate**.

### 2. Настройка App Group для обмена данными
Для того чтобы iOS-приложение и Watch Extension имели доступ к одной и той же базе данных/настройкам:
1. В Xcode выберите основной проект `Runner` в панели слева.
2. Перейдите на вкладку **Signing & Capabilities**.
3. Нажмите **+ Capability** и добавьте **App Groups**.
4. Добавьте новый идентификатор группы, например: `group.com.app.nutrilog.app.X4HMJXZ332`.
5. Повторите этот шаг для созданного **Watch Widget Target**.

### 3. Интеграция с существующим `HomeWidgetSyncService`
В вашем коде Flutter уже настроен сервис [home_widget_service.dart](file:///Users/aleksandrryzenkov/Desktop/NutriLog/lib/services/home_widget_service.dart), который записывает калории, белки, жиры, углеводы, шаги и воду через App Group:

```dart
await HomeWidget.setAppGroupId('group.com.app.nutrilog.app.X4HMJXZ332');
await HomeWidget.saveWidgetData('calories', '$consumed');
await HomeWidget.saveWidgetData('proteins', '$protein');
// ...и так далее.
```

### 4. SwiftUI код для виджета Apple Watch (watchOS)
Создайте или обновите Swift-файл вашего Watch Widget (например, `NutriLogWatchWidget.swift` в папке watchOS-таргета):

```swift
import WidgetKit
import SwiftUI

// Структура для чтения данных из общей App Group
struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let calories: Int
    let proteins: Int
    let fats: Int
    let carbs: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WatchWidgetEntry {
        WatchWidgetEntry(date: Date(), calories: 1200, proteins: 90, fats: 50, carbs: 150)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchWidgetEntry) -> ()) {
        let entry = readSharedData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = readSharedData()
        // Обновляем виджет каждые 15 минут
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readSharedData() -> WatchWidgetEntry {
        // Читаем UserDefaults из нашей App Group
        let sharedDefaults = UserDefaults(suiteName: "group.com.app.nutrilog.app.X4HMJXZ332")
        
        let calories = Int(sharedDefaults?.string(forKey: "calories") ?? "0") ?? 0
        let proteins = Int(sharedDefaults?.string(forKey: "proteins") ?? "0") ?? 0
        let fats = Int(sharedDefaults?.string(forKey: "fats") ?? "0") ?? 0
        let carbs = Int(sharedDefaults?.string(forKey: "carbs") ?? "0") ?? 0
        
        return WatchWidgetEntry(date: Date(), calories: calories, proteins: proteins, fats: fats, carbs: carbs)
    }
}

// Красивое премиальное SwiftUI отображение виджета (круговой прогресс)
struct NutriLogWatchWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0.0, to: min(CGFloat(entry.calories) / 2000.0, 1.0)) // Предположим цель 2000 ккал
                    .stroke(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
                
                VStack {
                    Text("\(entry.calories)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("ккал")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50, height: 50)
            
            HStack(spacing: 6) {
                Text("Б:\(entry.proteins)г")
                    .font(.system(size: 8, weight: .medium))
                Text("У:\(entry.carbs)г")
                    .font(.system(size: 8, weight: .medium))
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

@main
struct NutriLogWatchWidget: Widget {
    let kind: String = "NutriLogWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NutriLogWatchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NutriLog Активность")
        .description("Отслеживайте калории и БЖУ прямо на циферблате часов.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner])
    }
}
```

---

## Часть 3: Настройка виджета для Android Wear OS (Tiles)

Для Android-часов используются **Tiles** (плитки быстрого доступа), создаваемые на нативном Kotlin.

### 1. Добавление Wear OS модуля в проект
В корневой папке вашего Android-проекта (`android/`):
1. Создайте модуль для Wear OS или подключите Wear OS библиотеки в `android/app/build.gradle`:
```groovy
dependencies {
    // Библиотеки для поддержки плиток Wear OS Tiles
    implementation "androidx.wear.tiles:tiles:1.2.0"
    implementation "androidx.wear.tiles:tiles-material:1.2.0"
    implementation "androidx.wear.protolayout:protolayout:1.0.0"
    implementation "androidx.wear.protolayout:protolayout-material:1.0.0"
    
    // Передача данных Google Play Services Wearable
    implementation "com.google.android.gms:play-services-wearable:18.1.0"
}
```

### 2. Синхронизация через Shared Preferences / DataClient
Flutter-приложение передает данные с телефона на часы, используя `Wearable.getDataClient(context)` через `MethodChannel`, либо используя общий SharedPreferences, если это автономное Wear OS приложение.

В Kotlin на часах мы считываем записанные данные:
```kotlin
package com.nutrilog.app

import android.content.Context
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.android.gms.wearable.Wearable

class NutriLogTileService : TileService() {
    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val prefs = getSharedPreferences("com.nutrilog.app_preferences", Context.MODE_PRIVATE)
        val calories = prefs.getString("calories", "0") ?: "0"
        val water = prefs.getString("water", "0.0") ?: "0.0"

        // Строим красивый круглый Tile с прогресс-баром и текстом
        // на базе androidx.wear.protolayout.LayoutElementBuilders...
        
        return ...
    }
}
```

---

## Часть 4: Полезные советы из видео

1. **Бюджет обновлений (iOS reloadTimelines)**: watchOS жестко квотирует частоту фоновых обновлений. Благодаря дебаунсеру в вашем `HomeWidgetSyncService`, приложение обновляет виджеты только при реальном изменении баланса (например, когда пользователь записал новый прием пищи), сохраняя заряд батареи и лимиты ОС.
2. **Локальное кэширование**: Всегда держите кэш данных в часах. Если связь с телефоном временно отсутствует, часы должны показывать последние известные данные за сегодня, а не пустые экраны.
3. **Круговые шкалы**: Accessory Circular — самый популярный и красивый формат виджетов на Apple Watch. Градиент от синего к голубому отлично подчеркивает спортивно-оздоровительную эстетику приложения!
