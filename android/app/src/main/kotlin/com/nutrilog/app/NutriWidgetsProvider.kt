package com.nutrilog.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

private object NutriWidgetMapper {
    private fun intValue(data: SharedPreferences, key: String, fallback: Int = 0): Int {
        return data.getInt(key, fallback)
    }

    private fun stringValue(data: SharedPreferences, key: String, fallback: String = "0"): String {
        return data.getString(key, fallback) ?: fallback
    }

    fun bindSmall(views: RemoteViews, data: SharedPreferences) {
        val remaining = intValue(data, "widget_calories_remaining")
        val percent = intValue(data, "widget_calories_percent")

        views.setTextViewText(R.id.widgetCalories, "$remaining")
        views.setProgressBar(R.id.progressCalories, 100, percent.coerceIn(0, 100), false)
    }

    fun bindMedium(views: RemoteViews, data: SharedPreferences) {
        val remaining = intValue(data, "widget_calories_remaining")
        val consumed = intValue(data, "widget_calories_consumed")
        val goal = intValue(data, "widget_calories_goal")
        val percent = intValue(data, "widget_calories_percent")
        val activity = intValue(data, "widget_calories_activity")

        // Калории
        views.setTextViewText(R.id.widgetCalories, "$remaining")
        views.setProgressBar(R.id.progressCalories, 100, percent.coerceIn(0, 100), false)
        views.setTextViewText(R.id.tvGoal, "$goal")
        views.setTextViewText(R.id.tvCalories, "$consumed")
        views.setTextViewText(R.id.tvActivity, "$activity")

        // Макросы
        val carbs = intValue(data, "widget_carbs")
        val carbsGoal = intValue(data, "widget_carbs_goal")
        val carbsPercent = intValue(data, "widget_carbs_percent")
        views.setTextViewText(R.id.tvCarbs, "${carbs}г")
        views.setTextViewText(R.id.tvCarbsGoal, "/${carbsGoal}г")
        views.setProgressBar(R.id.progressCarbs, 100, carbsPercent.coerceIn(0, 100), false)

        val protein = intValue(data, "widget_protein")
        val proteinGoal = intValue(data, "widget_protein_goal")
        val proteinPercent = intValue(data, "widget_protein_percent")
        views.setTextViewText(R.id.tvProtein, "${protein}г")
        views.setTextViewText(R.id.tvProteinGoal, "/${proteinGoal}г")
        views.setProgressBar(R.id.progressProtein, 100, proteinPercent.coerceIn(0, 100), false)

        val fat = intValue(data, "widget_fat")
        val fatGoal = intValue(data, "widget_fat_goal")
        val fatPercent = intValue(data, "widget_fat_percent")
        views.setTextViewText(R.id.tvFat, "${fat}г")
        views.setTextViewText(R.id.tvFatGoal, "/${fatGoal}г")
        views.setProgressBar(R.id.progressFat, 100, fatPercent.coerceIn(0, 100), false)
    }

    fun bindLarge(views: RemoteViews, data: SharedPreferences) {
        bindMedium(views, data)
        
        // Дополнительные данные для большого виджета (вода)
        val waterLiters = stringValue(data, "widget_water_liters", "0.0")
        val waterGoalLiters = stringValue(data, "widget_water_goal_liters", "0.0")
        val intake = intValue(data, "widget_water_intake")
        val goal = intValue(data, "widget_water_goal")
        val waterPercent = if (goal > 0) (intake * 100 / goal) else 0

        views.setTextViewText(R.id.widgetWater, waterLiters)
        views.setTextViewText(R.id.tvWaterGoal, "$waterGoalLiters л")
        views.setProgressBar(R.id.progressWater, 100, waterPercent.coerceIn(0, 100), false)
    }

    fun bindWater(views: RemoteViews, data: SharedPreferences) {
        val waterLiters = stringValue(data, "widget_water_liters", "0.0")
        val waterGoalLiters = stringValue(data, "widget_water_goal_liters", "0.0")
        val intake = intValue(data, "widget_water_intake")
        val goal = intValue(data, "widget_water_goal")
        val percent = if (goal > 0) (intake * 100 / goal) else 0

        views.setTextViewText(R.id.widgetWater, waterLiters)
        views.setTextViewText(R.id.tvWaterGoal, "Цель: $waterGoalLiters л")
        views.setProgressBar(R.id.progressWater, 100, percent.coerceIn(0, 100), false)
    }
}

class NutriSmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_small)
            NutriWidgetMapper.bindSmall(views, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class NutriMediumWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_medium)
            NutriWidgetMapper.bindMedium(views, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class NutriLargeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_large)
            NutriWidgetMapper.bindLarge(views, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class NutriWaterWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_water)
            NutriWidgetMapper.bindWater(views, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
