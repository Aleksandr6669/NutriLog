---
name: NutriLog Project Instructions
description: "Основные правила и конвенции для разработки проекта NutriLog (Flutter Calorie Tracker)"
---

# NutriLog Project Instructions

Вы работаете над Flutter-приложением для отслеживания калорий с интеграцией ИИ.

## Архитектура
- **Models (`lib/models/`)**: Чистые Dart-классы для данных. Используют `fromJson`/`toJson`.
- **Services (`lib/services/`)**: Логика данных и API. Работают с `SharedPreferences` и локальными JSON.
- **Screens (`lib/screens/`)**: Основные страницы приложения.
- **Widgets (`lib/widgets/`)**: Переиспользуемые компоненты.
- **Styles (`lib/styles/`)**: Централизованное управление цветами и стилями (Material 3).

## Технологический стек
- **State Management**: `provider`
- **Routing**: `go_router`
- **Charts**: `fl_chart`
- **Icons**: `material_symbols_icons`
- **Fonts**: `google_fonts` (Inter/Montserrat)

## Правила кодинга
- Используйте `final` для переменных, которые не меняются.
- Следуйте стилю `flutter_lints`.
- UI должен быть минималистичным, в стиле iOS (чистые линии, мягкие тени, скругленные углы 20-30px).
- Все строки для перевода (пока) на русском языке.

## Работа с данными
- Данные о еде и рецептах хранятся в `assets/data/`.
- Пользовательские настройки и логи сохраняются через `SharedPreferences`.
