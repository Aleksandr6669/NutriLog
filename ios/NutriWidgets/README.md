# iOS WidgetKit setup for NutriLog

The Swift file in this folder contains the widget implementation in the same visual style and uses the same data keys that Flutter writes.

## Connect this to the iOS project (one-time)

1. Open Xcode for the iOS project.
2. Add a new target: `Widget Extension`.
3. Add `ios/NutriWidgets/NutriWidgets.swift` to the new target.
4. Enable App Groups for both targets:
   - Runner
   - Widget Extension
5. Use the same group id in both targets:
   - `group.com.example.myapp.nutrilog`
6. Build and run. The 4 widgets will be available:
   - NutriSmallWidget
   - NutriMediumWidget
   - NutriLargeWidget
   - NutriWaterWidget

## Data keys used

- widget_calories_consumed
- widget_calories_goal
- widget_calories_remaining
- widget_protein
- widget_protein_goal
- widget_fat
- widget_fat_goal
- widget_carbs
- widget_carbs_goal
- widget_water_liters
- widget_water_goal_liters
- widget_water_intake
- widget_water_goal

These keys are written from Flutter by `HomeWidgetSyncService`.
