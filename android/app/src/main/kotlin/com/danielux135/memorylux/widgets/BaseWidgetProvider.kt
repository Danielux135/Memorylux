package com.danielux135.memorylux.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import com.danielux135.memorylux.MainActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

// base común: refresco a medianoche (para que "hoy" y los vencidos se
// recalculen aunque la app no se abra) y helpers de intents
abstract class BaseWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_MIDNIGHT = "com.danielux135.memorylux.WIDGET_MIDNIGHT"

        fun scheduleMidnightUpdate(context: Context, cls: Class<*>) {
            val intent = Intent(context, cls).apply { action = ACTION_MIDNIGHT }
            val pending = PendingIntent.getBroadcast(
                context, cls.simpleName.hashCode(), intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val midnight = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.setInexactRepeating(
                AlarmManager.RTC, midnight.timeInMillis,
                AlarmManager.INTERVAL_DAY, pending,
            )
        }

        // pending intent que abre la app con un deep link de home_widget
        fun launchIntent(context: Context, uri: Uri? = null): PendingIntent =
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleMidnightUpdate(context, javaClass)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_MIDNIGHT) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, javaClass))
            if (ids.isNotEmpty()) {
                onUpdate(context, manager, ids, HomeWidgetPlugin.getData(context))
            }
            return
        }
        super.onReceive(context, intent)
    }
}
