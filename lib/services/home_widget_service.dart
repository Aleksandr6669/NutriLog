import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/daily_log.dart';
import '../models/user_profile.dart';

class HomeWidgetSyncService {
  static const String _iosAppGroup = 'group.com.app.nutrilog.app';

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
 
    // Initial sync might need App Group ID again just in case, but we moved it to main()
    // We'll keep it here as a fallback if Platform is iOS, but won't await it every time if it's already set.
    // Actually, calling it multiple times is safe and ensures the correct group is used.
    if (Platform.isIOS) {
      try {
        await HomeWidget.setAppGroupId(_iosAppGroup);
      } catch (_) {}
    }


    final Map<String, dynamic> data = {
      'calories': consumed.toString(),
      'proteins': '$proteinг',
      'fats': '$fatг',
      'carbs': '$carbsг',
      'proteins_val': protein.toString(),
      'fats_val': fat.toString(),
      'carbs_val': carbs.toString(),
      'calories_summary': '$consumed ккал',
      'water': '$waterLiters Л',
      'water_value': '$waterLiters Л',
      'steps': stepsString,
    };

    // Save all data
    await Future.wait(data.entries.map((e) => HomeWidget.saveWidgetData(e.key, e.value)));

    if (Platform.isAndroid) {
      try {
        await HomeWidget.updateWidget(
          androidName: 'NutriLargeWidgetProvider',
          qualifiedAndroidName: 'com.nutrilog.app.NutriLargeWidgetProvider'
        );
        await HomeWidget.updateWidget(
          androidName: 'NutriSmallWidgetProvider',
          qualifiedAndroidName: 'com.nutrilog.app.NutriSmallWidgetProvider'
        );
        await HomeWidget.updateWidget(
          androidName: 'NutriWaterWidgetProvider',
          qualifiedAndroidName: 'com.nutrilog.app.NutriWaterWidgetProvider'
        );
      } catch (_) {}
    } else if (Platform.isIOS) {
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
