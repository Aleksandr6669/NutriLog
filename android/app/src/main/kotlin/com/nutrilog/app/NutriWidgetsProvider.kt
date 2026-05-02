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



class NutriLargeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_large)
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

class NutriSmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nutri_widget_small)
            try {
                views.setTextViewText(R.id.widgetCalories, widgetData.getString("calories", "0"))
                // For small widget we use values without 'г' if available, or just proteins
                views.setTextViewText(R.id.widgetProteins, widgetData.getString("proteins_val", "0"))
                views.setTextViewText(R.id.widgetFats, widgetData.getString("fats_val", "0"))
                views.setTextViewText(R.id.widgetCarbs, widgetData.getString("carbs_val", "0"))
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


