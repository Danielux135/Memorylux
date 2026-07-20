package com.danielux135.memorylux.widgets

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.danielux135.memorylux.R

// widget 4x4: zona configurable + fila de nueva nota
class BoardWidgetProvider : AbstractListWidgetProvider() {
    override val layoutRes get() = R.layout.widget_board
    override val jsonKey get() = "widget_board_json"
    override val titleKey get() = "widget_board_title"

    override fun decorate(
        context: Context,
        views: RemoteViews,
        widgetData: SharedPreferences,
        colors: WidgetColors,
    ) {
        views.setTextViewText(
            R.id.widget_add_label,
            widgetData.getString("widget_add_label", "") ?: "",
        )
        views.setTextColor(R.id.widget_add_label, colors.accent)
        views.setOnClickPendingIntent(
            R.id.widget_add_row,
            launchIntent(context, Uri.parse("memorylux://new")),
        )
    }
}
