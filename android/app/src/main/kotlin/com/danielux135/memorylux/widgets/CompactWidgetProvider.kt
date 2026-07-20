package com.danielux135.memorylux.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.danielux135.memorylux.R

// widget 2x2: pendientes de hoy + racha sobre un post-it
class CompactWidgetProvider : BaseWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val colors = WidgetTheme.postit(widgetData)
        val count = WidgetTheme.readInt(widgetData, "widget_pending_count", 0)
        val streak = WidgetTheme.readInt(widgetData, "widget_streak", 0)
        val showStreak = widgetData.getBoolean("widget_show_streak", true)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_compact)
            views.setInt(R.id.widget_bg, "setColorFilter", colors.background)
            views.setInt(R.id.widget_bg, "setImageAlpha", colors.alpha)

            views.setTextViewText(
                R.id.widget_date,
                widgetData.getString("widget_date_label", "") ?: "",
            )
            views.setTextColor(R.id.widget_date, colors.subtext)

            views.setTextViewText(R.id.widget_count, count.toString())
            views.setTextColor(R.id.widget_count, colors.text)

            views.setTextViewText(
                R.id.widget_count_label,
                widgetData.getString("widget_pending_label", "") ?: "",
            )
            views.setTextColor(R.id.widget_count_label, colors.subtext)

            if (showStreak && streak > 0) {
                views.setViewVisibility(R.id.widget_streak_row, View.VISIBLE)
                views.setTextViewText(R.id.widget_streak, streak.toString())
                views.setTextColor(R.id.widget_streak, colors.text)
            } else {
                views.setViewVisibility(R.id.widget_streak_row, View.GONE)
            }

            views.setOnClickPendingIntent(
                R.id.widget_root,
                launchIntent(context, Uri.parse("memorylux://open")),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
