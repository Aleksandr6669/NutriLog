import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/daily_log.dart';
import '../models/user_profile.dart';

class HomeWidgetSyncService {
  static const String _iosAppGroup = 'group.com.nutrilog.app.nutrilog';

  Future<void> syncDailyData({
    required DailyLog log,
    required UserProfile profile,
  }) async {
    // Widgets are currently only implemented for Android.
    // Skip for Web and other platforms to prevent MissingPluginException.
    if (kIsWeb || !Platform.isAndroid) return;
    final consumed = log.totalNutrients.calories.round();
    final activity = log.activityCalories;
    final effectiveConsumed = (consumed - activity).clamp(0, 99999);
    final remaining = profile.calorieGoal - effectiveConsumed;

    final carbs = log.totalNutrients.carbs.round();
    final protein = log.totalNutrients.protein.round();
    final fat = log.totalNutrients.fat.round();

    final waterLiters = (log.waterIntake / 1000).toStringAsFixed(1);
    final steps = log.steps.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );

    try {
      await HomeWidget.setAppGroupId(_iosAppGroup);
    } catch (_) {}

    await Future.wait([
      // New Keys for our Card Widgets
      HomeWidget.saveWidgetData<String>('calories', consumed.toString()),
      HomeWidget.saveWidgetData<String>('proteins', '${protein}г'),
      HomeWidget.saveWidgetData<String>('fats', '${fat}г'),
      HomeWidget.saveWidgetData<String>('carbs', '${carbs}г'),
      HomeWidget.saveWidgetData<String>('calories_summary', '${consumed} ккал'),
      HomeWidget.saveWidgetData<String>('water', '$waterLiters Л'),
      HomeWidget.saveWidgetData<String>('water_value', '$waterLiters Л'),
      HomeWidget.saveWidgetData<String>('steps', steps),
      
      // Keep legacy keys if needed elsewhere
      HomeWidget.saveWidgetData<int>('widget_calories_consumed', consumed),
      HomeWidget.saveWidgetData<int>('widget_water_intake', log.waterIntake),
    ]);

    await Future.wait([
      HomeWidget.updateWidget(androidName: 'NutriSmallWidgetProvider'),
      HomeWidget.updateWidget(androidName: 'NutriMediumWidgetProvider'),
      HomeWidget.updateWidget(androidName: 'NutriLargeWidgetProvider'),
      HomeWidget.updateWidget(androidName: 'NutriWaterWidgetProvider'),
    ]);
  }
}
