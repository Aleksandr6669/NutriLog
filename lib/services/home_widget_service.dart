import 'package:home_widget/home_widget.dart';

import '../models/daily_log.dart';
import '../models/user_profile.dart';

class HomeWidgetSyncService {
  static const String _iosAppGroup = 'group.com.nutrilog.app.nutrilog';

  Future<void> syncDailyData({
    required DailyLog log,
    required UserProfile profile,
  }) async {
    final consumed = log.totalNutrients.calories.round();
    final activity = log.activityCalories;
    final effectiveConsumed = (consumed - activity).clamp(0, 99999);
    final remaining = profile.calorieGoal - effectiveConsumed;

    final carbs = log.totalNutrients.carbs.round();
    final protein = log.totalNutrients.protein.round();
    final fat = log.totalNutrients.fat.round();

    final waterIntake = log.waterIntake;
    final waterGoal = profile.waterGoal;
    final waterLiters = (waterIntake / 1000).toStringAsFixed(1);
    final waterGoalLiters = (waterGoal / 1000).toStringAsFixed(1);

    final caloriesPercent = profile.calorieGoal > 0
        ? ((effectiveConsumed / profile.calorieGoal) * 100)
            .round()
            .clamp(0, 999)
        : 0;

    final carbsPercent = profile.carbsGoal > 0
        ? ((carbs / profile.carbsGoal) * 100).round().clamp(0, 100)
        : 0;
    final proteinPercent = profile.proteinGoal > 0
        ? ((protein / profile.proteinGoal) * 100).round().clamp(0, 100)
        : 0;
    final fatPercent = profile.fatGoal > 0
        ? ((fat / profile.fatGoal) * 100).round().clamp(0, 100)
        : 0;

    try {
      await HomeWidget.setAppGroupId(_iosAppGroup);
    } catch (_) {
      // Android does not require app group setup.
    }

    await Future.wait([
      HomeWidget.saveWidgetData<String>('widget_title', 'NutriLog'),
      HomeWidget.saveWidgetData<int>(
          'widget_calories_goal', profile.calorieGoal),
      HomeWidget.saveWidgetData<int>(
          'widget_calories_consumed', consumed), // Raw consumed for the icon block
      HomeWidget.saveWidgetData<int>(
          'widget_calories_effective', effectiveConsumed), // For the circle
      HomeWidget.saveWidgetData<int>('widget_calories_activity', activity),
      HomeWidget.saveWidgetData<int>('widget_calories_remaining', remaining),
      HomeWidget.saveWidgetData<int>(
          'widget_calories_percent', caloriesPercent),
      HomeWidget.saveWidgetData<int>('widget_carbs', carbs),
      HomeWidget.saveWidgetData<int>('widget_carbs_goal', profile.carbsGoal),
      HomeWidget.saveWidgetData<int>('widget_carbs_percent', carbsPercent),
      HomeWidget.saveWidgetData<int>('widget_protein', protein),
      HomeWidget.saveWidgetData<int>(
          'widget_protein_goal', profile.proteinGoal),
      HomeWidget.saveWidgetData<int>('widget_protein_percent', proteinPercent),
      HomeWidget.saveWidgetData<int>('widget_fat', fat),
      HomeWidget.saveWidgetData<int>('widget_fat_goal', profile.fatGoal),
      HomeWidget.saveWidgetData<int>('widget_fat_percent', fatPercent),
      HomeWidget.saveWidgetData<int>('widget_water_intake', waterIntake),
      HomeWidget.saveWidgetData<int>('widget_water_goal', waterGoal),
      HomeWidget.saveWidgetData<String>('widget_water_liters', waterLiters),
      HomeWidget.saveWidgetData<String>(
          'widget_water_goal_liters', waterGoalLiters),
    ]);

    await Future.wait([
      HomeWidget.updateWidget(
        androidName: 'NutriSmallWidgetProvider',
        iOSName: 'NutriSmallWidget',
      ),
      HomeWidget.updateWidget(
        androidName: 'NutriMediumWidgetProvider',
        iOSName: 'NutriMediumWidget',
      ),
      HomeWidget.updateWidget(
        androidName: 'NutriLargeWidgetProvider',
        iOSName: 'NutriLargeWidget',
      ),
      HomeWidget.updateWidget(
        androidName: 'NutriWaterWidgetProvider',
        iOSName: 'NutriWaterWidget',
      ),
    ]);
  }
}
