package com.nutrilog.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import com.nutrilog.app.R

/**
 * Consolidated Widget Providers for NutriLog
 */

class NutriSmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_small)
            try {
                views.setTextViewText(R.id.widgetCalories, widgetData.getString("calories", "0"))
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                // Fail silently or log
            }
        }
    }
}

class NutriMediumWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_medium)
            try {
                views.setTextViewText(R.id.widgetCalories, widgetData.getString("calories", "0"))
                views.setTextViewText(R.id.widgetProteins, widgetData.getString("proteins", "0г"))
                views.setTextViewText(R.id.widgetFats, widgetData.getString("fats", "0г"))
                views.setTextViewText(R.id.widgetCarbs, widgetData.getString("carbs", "0г"))
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) { }
        }
    }
}

class NutriLargeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_large)
            try {
                views.setTextViewText(R.id.widgetCalories, widgetData.getString("calories_summary", "0 ккал"))
                views.setTextViewText(R.id.widgetWater, widgetData.getString("water", "0.0 Л"))
                views.setTextViewText(R.id.widgetSteps, widgetData.getString("steps", "0"))
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) { }
        }
    }
}

class NutriWaterWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_water)
            try {
                views.setTextViewText(R.id.widgetWaterValue, widgetData.getString("water_value", "0.0 Л"))
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) { }
        }
    }
}

class NutriTestWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_test)
            try {
                views.setTextViewText(R.id.widgetText, "TEST OK")
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) { }
        }
    }
}
