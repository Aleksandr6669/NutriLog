import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/daily_log.dart';
import '../models/user_profile.dart';

class HomeWidgetSyncService {
  static const String _iosAppGroup = 'group.com.nutrilog.app';

  Future<void> syncDailyData({
    required DailyLog log,
    required UserProfile profile,
  }) async {
    // Skip for Web and desktop to prevent MissingPluginException.
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    
    final consumed = log.totalNutrients.calories.round();
    final carbs = log.totalNutrients.carbs.round();
    final protein = log.totalNutrients.protein.round();
    final fat = log.totalNutrients.fat.round();

    final waterLiters = (log.waterIntake / 1000).toStringAsFixed(1);
    final stepsValue = log.steps;
    final stepsString = stepsValue.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );

    try {
      await HomeWidget.setAppGroupId(_iosAppGroup);
    } catch (_) {}

    await Future.wait([
      // Data for Android (mostly Strings)
      HomeWidget.saveWidgetData<String>('calories', consumed.toString()),
      HomeWidget.saveWidgetData<String>('proteins', '$proteinг'),
      HomeWidget.saveWidgetData<String>('fats', '$fatг'),
      HomeWidget.saveWidgetData<String>('carbs', '$carbsг'),
      HomeWidget.saveWidgetData<String>('calories_summary', '$consumed ккал'),
      HomeWidget.saveWidgetData<String>('water', '$waterLiters Л'),
      HomeWidget.saveWidgetData<String>('water_value', '$waterLiters Л'),
      HomeWidget.saveWidgetData<String>('steps', stepsString),
      
      // Data for iOS (Ints)
      HomeWidget.saveWidgetData<int>('calories', consumed),
      HomeWidget.saveWidgetData<int>('proteins', protein),
      HomeWidget.saveWidgetData<int>('fats', fat),
      HomeWidget.saveWidgetData<int>('carbs', carbs),
      HomeWidget.saveWidgetData<int>('steps_value', stepsValue),
    ]);

    await Future.wait([
      // Android Updates
      HomeWidget.updateWidget(androidName: 'NutriSmallWidgetProvider'),
      HomeWidget.updateWidget(androidName: 'NutriMediumWidgetProvider'),
      HomeWidget.updateWidget(androidName: 'NutriLargeWidgetProvider'),
      HomeWidget.updateWidget(androidName: 'NutriWaterWidgetProvider'),
      // iOS Update
      HomeWidget.updateWidget(iOSName: 'NutriLogWidget'),
    ]);
  }
}
