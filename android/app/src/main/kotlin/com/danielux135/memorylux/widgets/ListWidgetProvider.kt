package com.danielux135.memorylux.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.danielux135.memorylux.MainActivity
import com.danielux135.memorylux.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent

// base de los widgets con lista (4x2 y 4x4); las subclases indican layout,
// clave del json y título
abstract class AbstractListWidgetProvider : BaseWidgetProvider() {

    abstract val layoutRes: Int
    abstract val jsonKey: String
    abstract val titleKey: String

    open fun decorate(
        context: Context,
        views: RemoteViews,
        widgetData: SharedPreferences,
        colors: WidgetColors,
    ) {}

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val colors = WidgetTheme.surface(context, widgetData)
        val streak = WidgetTheme.readInt(widgetData, "widget_streak", 0)
        val showStreak = widgetData.getBoolean("widget_show_streak", true)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutRes)
            views.setInt(R.id.widget_bg, "setColorFilter", colors.background)
            views.setInt(R.id.widget_bg, "setImageAlpha", colors.alpha)

            views.setTextViewText(
                R.id.widget_title,
                widgetData.getString(titleKey, "") ?: "",
            )
            views.setTextColor(R.id.widget_title, colors.text)

            if (showStreak && streak > 0) {
                views.setViewVisibility(R.id.widget_streak_row, View.VISIBLE)
                views.setTextViewText(R.id.widget_streak, streak.toString())
                views.setTextColor(R.id.widget_streak, colors.text)
            } else {
                views.setViewVisibility(R.id.widget_streak_row, View.GONE)
            }

            // adaptador remoto: el data uri hace único el intent por widget/clave
            val svcIntent = Intent(context, MemoryListService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                putExtra(MemoryListService.EXTRA_JSON_KEY, jsonKey)
                data = Uri.parse("memorylux://list/$jsonKey/$id")
            }
            views.setRemoteAdapter(R.id.widget_items, svcIntent)
            views.setEmptyView(R.id.widget_items, R.id.widget_empty)
            views.setTextViewText(
                R.id.widget_empty,
                widgetData.getString("widget_empty_label", "") ?: "",
            )
            views.setTextColor(R.id.widget_empty, colors.subtext)

            // plantilla mutable para que las filas rellenen su uri
            val template = Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 31) flags = flags or PendingIntent.FLAG_MUTABLE
            views.setPendingIntentTemplate(
                R.id.widget_items,
                PendingIntent.getActivity(context, id, template, flags),
            )

            decorate(context, views, widgetData, colors)
            appWidgetManager.updateAppWidget(id, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.widget_items)
        }
    }
}

// widget 4x2: tareas de hoy
class ListWidgetProvider : AbstractListWidgetProvider() {
    override val layoutRes get() = R.layout.widget_list
    override val jsonKey get() = "widget_today_json"
    override val titleKey get() = "widget_today_title"
}
