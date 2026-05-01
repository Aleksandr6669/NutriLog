package com.nutrilog.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Consolidated Widget Providers for NutriLog
 */

class NutriSmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_small).apply {
                setTextViewText(R.id.widgetCalories, widgetData.getString("calories", "0"))
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

class NutriMediumWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_medium).apply {
                setTextViewText(R.id.widgetCalories, widgetData.getString("calories", "0"))
                setTextViewText(R.id.widgetProteins, widgetData.getString("proteins", "0г"))
                setTextViewText(R.id.widgetFats, widgetData.getString("fats", "0г"))
                setTextViewText(R.id.widgetCarbs, widgetData.getString("carbs", "0г"))
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

class NutriLargeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_large).apply {
                setTextViewText(R.id.widgetCalories, widgetData.getString("calories_summary", "0 ккал"))
                setTextViewText(R.id.widgetWater, widgetData.getString("water", "0.0 Л"))
                setTextViewText(R.id.widgetSteps, widgetData.getString("steps", "0"))
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

class NutriWaterWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_water).apply {
                setTextViewText(R.id.widgetWaterValue, widgetData.getString("water_value", "0.0 Л"))
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
