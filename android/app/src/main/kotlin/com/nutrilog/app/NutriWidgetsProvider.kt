package com.nutrilog.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
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
        val consumed = intValue(data, "widget_calories_consumed")
        val goal = intValue(data, "widget_calories_goal")

        views.setTextViewText(R.id.widgetTitle, "Дневная цель")
        views.setTextViewText(R.id.widgetMainValue, "$remaining")
        views.setTextViewText(R.id.widgetSubValue, "Осталось ккал")
        views.setTextViewText(R.id.widgetMeta, "$consumed / $goal ккал")
    }

    fun bindMedium(views: RemoteViews, data: SharedPreferences) {
        val consumed = intValue(data, "widget_calories_consumed")
        val goal = intValue(data, "widget_calories_goal")

        views.setTextViewText(R.id.widgetTitle, "NutriLog")
        views.setTextViewText(R.id.widgetCalories, "$consumed / $goal ккал")
        views.setTextViewText(
            R.id.widgetMacros,
            "Б ${intValue(data, "widget_protein")}/${intValue(data, "widget_protein_goal")}  " +
                "Ж ${intValue(data, "widget_fat")}/${intValue(data, "widget_fat_goal")}  " +
                "У ${intValue(data, "widget_carbs")}/${intValue(data, "widget_carbs_goal")}",
        )
    }

    fun bindLarge(views: RemoteViews, data: SharedPreferences) {
        val remaining = intValue(data, "widget_calories_remaining")
        val consumed = intValue(data, "widget_calories_consumed")
        val goal = intValue(data, "widget_calories_goal")

        views.setTextViewText(R.id.widgetTitle, "Дневные цели")
        views.setTextViewText(R.id.widgetMainValue, "$remaining ккал")
        views.setTextViewText(R.id.widgetSubValue, "Осталось")
        views.setTextViewText(R.id.widgetMeta, "Съедено: $consumed / $goal")
        views.setTextViewText(
            R.id.widgetMacros,
            "Белки: ${intValue(data, "widget_protein")}/${intValue(data, "widget_protein_goal")} г\n" +
                "Жиры: ${intValue(data, "widget_fat")}/${intValue(data, "widget_fat_goal")} г\n" +
                "Углеводы: ${intValue(data, "widget_carbs")}/${intValue(data, "widget_carbs_goal")} г",
        )
        views.setTextViewText(
            R.id.widgetWater,
            "Вода: ${stringValue(data, "widget_water_liters", "0.0")} / " +
                "${stringValue(data, "widget_water_goal_liters", "0.0")} л",
        )
    }

    fun bindWater(views: RemoteViews, data: SharedPreferences) {
        views.setTextViewText(R.id.widgetTitle, "Вода")
        views.setTextViewText(
            R.id.widgetMainValue,
            "${stringValue(data, "widget_water_liters", "0.0")} / " +
                "${stringValue(data, "widget_water_goal_liters", "0.0")} л",
        )
        views.setTextViewText(R.id.widgetSubValue, "Дневной баланс")
        views.setTextViewText(
            R.id.widgetMeta,
            "${intValue(data, "widget_water_intake")} из ${intValue(data, "widget_water_goal")} мл",
        )
    }
}

class NutriSmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_small)
            NutriWidgetMapper.bindSmall(views, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class NutriMediumWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_medium)
            NutriWidgetMapper.bindMedium(views, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class NutriLargeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_large)
            NutriWidgetMapper.bindLarge(views, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class NutriWaterWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_water)
            NutriWidgetMapper.bindWater(views, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
