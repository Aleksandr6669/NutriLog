import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class HomeWidgetUtils {
  static Future<void> updateWaterWidget(
      {required double current,
      required double goal,
      required int reminders,
      required int totalReminders}) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await HomeWidget.saveWidgetData('water_current', current);
    await HomeWidget.saveWidgetData('water_goal', goal);
    await HomeWidget.saveWidgetData('water_reminders', reminders);
    await HomeWidget.saveWidgetData('water_total_reminders', totalReminders);
    await HomeWidget.updateWidget(
        name: 'NutriWidgetProvider', iOSName: 'NutriWidget');
  }
}
