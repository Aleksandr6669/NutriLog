## Calorie Tracker App Blueprint

### Overview

This document outlines the structure and design of the Calorie Tracker Flutter application. The app is designed to help users track their daily caloric intake, monitor their nutritional progress, and analyze their activity levels. The UI is modern, clean, and intuitive, with a design inspired by the provided screenshots.

### Core Features & Design

**1. Diary Screen (`lib/screens/diary/diary_screen.dart`)**

*   **Purpose:** The main dashboard for the user, showing a summary of their daily progress.
*   **Design:**
    *   **AppBar:** Displays the title "Сегодня" with a calendar icon and includes notification and search icons.
    *   **Calorie Progress:** A large circular progress indicator shows remaining calories. Below it, stats for food, exercise, and goal are displayed.
    *   **Macronutrients:** Horizontal bars show the progress for carbohydrates, proteins, and fats.
    *   **Meal Logging:** Cards for Завтрак, Обед, Ужин, and Перекус. Each card shows recommended and consumed calories, with a `+` button to add food.

**2. Search Screen (`lib/screens/search/search_screen.dart`)**

*   **Purpose:** Allows users to search for food items to add to their diary and access the AI recognition feature.
*   **Design:**
    *   **AppBar:** Titled "Поиск продуктов".
    *   **AI Search Button:** A prominent button to navigate to the AI food recognition screen.

**3. Recognition Screen (`lib/screens/recognition/recognition_screen.dart`)**

*   **Purpose:** To identify a food item from an image using the Gemini API and allow the user to add it to their diary.
*   **Design:**
    *   **Image Picker:** A large, interactive area to pick an image from the gallery.
    *   **Image Preview:** Displays the selected image.
    *   **Analysis Result:** Shows the name of the food and its calorie count as identified by the AI.
    *   **Loading Indicator:** A spinner is displayed while the AI is analyzing the image.
    *   **Add to Diary:** A button to save the recognized food to the user's diary.

**4. Details Screen (`lib/screens/details/details_screen.dart`)**

*   **Purpose:** To show detailed information about a specific food item.
*   **Design:**
    *   **Image Header:** A curved image of the food item.
    *   **Title:** Displays the calorie count, name, and serving size.
    *   **Macronutrients:** A more detailed breakdown of proteins, fats, and carbs.
    *   **Vitamins and Minerals:** Chips displaying key vitamins and minerals.
    *   **Nutritional Value:** A list of other nutritional information like cholesterol and sodium.
    *   **Bottom Bar:** An "Добавить в дневник" button.

**5. Analysis Screen (`lib/screens/analysis/analysis_screen.dart`)**

*   **Purpose:** Provides the user with an analysis of their progress over time.
*   **Design:**
    *   **AppBar:** Titled "Анализ" with a back arrow and a share icon.
    *   **Time Toggle:** Buttons to switch between Day, Week, and Month views.
    *   **Weight Chart:** A line chart showing the user's weight progress.
    *   **Stats Cards:** Cards for average steps and daily water intake.
    *   **Weekly Activity:** A list of the user's activities for the week.

**6. Profile Screen (`lib/screens/profile/profile_screen.dart`)**

*   **Purpose:** The user's profile page, with access to settings and personal information.
*   **Design:**
    *   **Profile Header:** The user's profile picture, name, and subscription status.
    *   **Stats Cards:** Cards for weight and daily calorie norm.
    *   **Activity Level:** A card indicating the user's activity level.
    *   **Settings Section:** A list of settings options: Личные данные, Уведомления, Приватность, and Выйти.

### Current Task: Implement AI Food Recognition

**Plan:**

1.  **Dependencies**: Added `image_picker` and `firebase_ai` to `pubspec.yaml`.
2.  **Recognition Screen**: Created `lib/screens/recognition/recognition_screen.dart` with UI for image selection and analysis via Gemini.
3.  **Search Screen**: Created `lib/screens/search/search_screen.dart` as a placeholder to launch the recognition screen.
4.  **Navigation**: Updated `lib/main.dart` to include routes for the new screens and updated the bottom navigation bar to include a "Поиск" tab.

### Navigation

*   **`lib/main.dart`:** The main entry point of the application.
*   **`GoRouter`:** Used for declarative routing between screens.
*   **Bottom Navigation Bar:** Provides quick access to the Diary, Search, Analysis, and Profile screens.