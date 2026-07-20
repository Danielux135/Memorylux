package com.danielux135.memorylux.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.danielux135.memorylux.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

// sirve las filas de los widgets de lista leyendo el json guardado por flutter
class MemoryListService : RemoteViewsService() {
    companion object {
        const val EXTRA_JSON_KEY = "json_key"
    }

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        MemoryListFactory(
            applicationContext,
            intent.getStringExtra(EXTRA_JSON_KEY) ?: "widget_today_json",
        )
}

private data class RowItem(
    val id: String,
    val title: String,
    val time: String,
    val color: Int,
    val priority: String,
    val overdue: Boolean,
)

private class MemoryListFactory(
    private val context: Context,
    private val jsonKey: String,
) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<RowItem> = emptyList()
    private var colors = WidgetTheme.surface(context, HomeWidgetPlugin.getData(context))

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        colors = WidgetTheme.surface(context, prefs)
        val now = System.currentTimeMillis()
        items = try {
            val arr = JSONArray(prefs.getString(jsonKey, "[]") ?: "[]")
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                val due = o.optLong("dueEpoch", 0L)
                RowItem(
                    id = o.optString("id"),
                    title = o.optString("title"),
                    time = o.optString("time"),
                    color = WidgetTheme.parseColor(
                        o.optString("color"), 0xFFFFE082.toInt()),
                    priority = o.optString("priority", "normal"),
                    // el vencimiento se recalcula aquí para que el refresco de
                    // medianoche marque bien las tareas sin reabrir la app
                    overdue = o.optBoolean("overdue") || (due > 0 && due < now),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    override fun getViewAt(position: Int): RemoteViews {
        val item = items[position]
        val row = RemoteViews(context.packageName, R.layout.widget_list_item)

        row.setTextViewText(R.id.item_title, item.title)
        row.setTextColor(
            R.id.item_title,
            if (item.overdue) 0xFFE53935.toInt() else colors.text,
        )

        if (item.time.isNotEmpty()) {
            row.setViewVisibility(R.id.item_time, View.VISIBLE)
            row.setTextViewText(R.id.item_time, item.time)
            row.setTextColor(R.id.item_time, colors.subtext)
        } else {
            row.setViewVisibility(R.id.item_time, View.GONE)
        }

        row.setInt(R.id.item_dot, "setColorFilter", item.color)
        row.setInt(R.id.item_check, "setColorFilter", colors.subtext)
        row.setViewVisibility(
            R.id.item_priority,
            if (item.priority == "normal") View.GONE else View.VISIBLE,
        )

        // el tap del texto abre la nota; el check la marca como hecha (la app
        // se abre y procesa el uri vía widgetClicked)
        row.setOnClickFillInIntent(
            R.id.item_text_area,
            Intent().setData(Uri.parse("memorylux://open?id=${item.id}")),
        )
        row.setOnClickFillInIntent(
            R.id.item_check,
            Intent().setData(Uri.parse("memorylux://done?id=${item.id}")),
        )
        return row
    }

    override fun getCount() = items.size
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount() = 1
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = false
    override fun onDestroy() {}
}
