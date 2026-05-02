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

    if (Platform.isAndroid) {
      // Android: save strings
      await Future.wait([
        HomeWidget.saveWidgetData<String>('calories', consumed.toString()),
        HomeWidget.saveWidgetData<String>('proteins', '$proteinг'),
        HomeWidget.saveWidgetData<String>('fats', '$fatг'),
        HomeWidget.saveWidgetData<String>('carbs', '$carbsг'),
        HomeWidget.saveWidgetData<String>('proteins_val', protein.toString()),
        HomeWidget.saveWidgetData<String>('fats_val', fat.toString()),
        HomeWidget.saveWidgetData<String>('carbs_val', carbs.toString()),
        HomeWidget.saveWidgetData<String>('calories_summary', '$consumed ккал'),
        HomeWidget.saveWidgetData<String>('water', '$waterLiters Л'),
        HomeWidget.saveWidgetData<String>('water_value', '$waterLiters Л'),
        HomeWidget.saveWidgetData<String>('steps', stepsString),
      ]);
      // Use fully-qualified class names to avoid ClassNotFoundException when
      // the package context resolves to null in background isolates.
      const pkg = 'com.nutrilog.app';
      for (final cls in [
        '$pkg.NutriLargeWidgetProvider',
        '$pkg.NutriWaterWidgetProvider',
      ]) {
        try {
          await HomeWidget.updateWidget(androidName: cls);
        } catch (_) {}
      }
    } else if (Platform.isIOS) {
      // iOS: save ints
      await Future.wait([
        HomeWidget.saveWidgetData<int>('calories', consumed),
        HomeWidget.saveWidgetData<int>('proteins', protein),
        HomeWidget.saveWidgetData<int>('fats', fat),
        HomeWidget.saveWidgetData<int>('carbs', carbs),
        HomeWidget.saveWidgetData<int>('steps_value', stepsValue),
        HomeWidget.saveWidgetData<String>('water', '$waterLiters Л'),
      ]);
      try {
        await HomeWidget.updateWidget(
          name: 'NutriLogWidget',
          iOSName: 'NutriLogWidget',
        );
        await HomeWidget.updateWidget(
          name: 'NutriLogWaterWidget',
          iOSName: 'NutriLogWaterWidget',
        );
      } catch (_) {}
    }
  }
}
