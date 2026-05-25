import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../models/daily_log.dart';
import '../models/user_profile.dart';
import 'daily_log_service.dart';

class HomeWidgetSyncService {
  static const String _iosAppGroup = 'group.com.app.nutrilog.app';

  /// Нативный канал для принудительного сброса UserDefaults + reloadTimelines.
  /// WidgetReloadPlugin вызывает synchronize() перед reloadTimelines — это
  /// решает проблему когда home_widget записывает данные, но WidgetKit
  /// читает устаревший кэш.
  static const MethodChannel _iosReloadChannel =
      MethodChannel('com.app.nutrilog.app/widget_reload');

  /// Виджет на домашнем экране всегда показывает данные за сегодня.
  Future<void> syncDailyData({
    required DailyLog log,
    required UserProfile profile,
    bool forceReload = true,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final today = DateTime.now();
    final DailyLog widgetLog = _isSameDay(log.date, today)
        ? log
        : await DailyLogService().getLogForDate(today);

    final consumed = widgetLog.totalNutrients.calories.round();
    final carbs = widgetLog.totalNutrients.carbs.round();
    final protein = widgetLog.totalNutrients.protein.round();
    final fat = widgetLog.totalNutrients.fat.round();

    final waterLiters = (widgetLog.waterIntake / 1000).toStringAsFixed(1);
    final stepsValue = widgetLog.steps;
    final stepsString = stepsValue.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );

    if (Platform.isIOS) {
      try {
        await HomeWidget.setAppGroupId(_iosAppGroup);
      } catch (e, stack) {
        debugPrint('HOME_WIDGET: setAppGroupId failed: $e');
        debugPrint(stack.toString());
        return;
      }
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

    debugPrint('HOME_WIDGET: 📊 syncDailyData called — calories=$consumed, protein=$protein, fat=$fat, carbs=$carbs, water=$waterLiters');

    for (final entry in data.entries) {
      final saved = await HomeWidget.saveWidgetData(entry.key, entry.value);
      if (saved != true) {
        debugPrint(
            'HOME_WIDGET: saveWidgetData failed for key "${entry.key}"');
      }
    }

    if (Platform.isAndroid) {
      if (forceReload) {
        try {
          await HomeWidget.updateWidget(
              androidName: 'NutriLargeWidgetProvider',
              qualifiedAndroidName: 'com.nutrilog.app.NutriLargeWidgetProvider');
          await HomeWidget.updateWidget(
              androidName: 'NutriSmallWidgetProvider',
              qualifiedAndroidName: 'com.nutrilog.app.NutriSmallWidgetProvider');
          await HomeWidget.updateWidget(
              androidName: 'NutriWaterWidgetProvider',
              qualifiedAndroidName: 'com.nutrilog.app.NutriWaterWidgetProvider');
        } catch (e, stack) {
          debugPrint('HOME_WIDGET: updateWidget failed: $e');
          debugPrint(stack.toString());
        }
      }
    } else if (Platform.isIOS) {
      if (forceReload) {
        await _reloadIosWidgets();
      }
    }
  }

  Future<void> _reloadIosWidgets() async {
    // Сначала пробуем нативный канал — он вызывает UserDefaults.synchronize()
    // ПЕРЕД reloadTimelines, что гарантирует что виджет увидит свежие данные.
    try {
      await _iosReloadChannel.invokeMethod('flushAndReload');
      debugPrint('HOME_WIDGET: native flushAndReload успешно');
      return;
    } catch (e) {
      debugPrint('HOME_WIDGET: native channel failed ($e), fallback to home_widget');
    }

    // Fallback: стандартный путь через home_widget
    try {
      await HomeWidget.updateWidget(iOSName: 'NutriLogWidget');
      await HomeWidget.updateWidget(iOSName: 'NutriLogWaterWidget');
    } catch (e, stack) {
      debugPrint('HOME_WIDGET: iOS reload failed: $e');
      debugPrint(stack.toString());
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
