package com.danielux135.memorylux.widgets

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color

// colores resueltos para pintar un widget según la config guardada por flutter
data class WidgetColors(
    val background: Int,
    val text: Int,
    val subtext: Int,
    val accent: Int,
    val alpha: Int, // 0..255 aplicado al fondo
)

object WidgetTheme {
    private const val ACCENT = 0xFFFFB300.toInt()

    // paleta del tema de la app (app_theme.dart)
    private const val DARK_SURFACE = 0xFF262029.toInt()
    private const val DARK_INK = 0xFFF2EBDF.toInt()
    private const val LIGHT_SURFACE = 0xFFF7F1E5.toInt()
    private const val LIGHT_INK = 0xFF2B2118.toInt()

    fun isDark(context: Context, prefs: SharedPreferences): Boolean {
        return when (prefs.getString("widget_theme", "auto")) {
            "light" -> false
            "dark" -> true
            else -> (context.resources.configuration.uiMode and
                Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        }
    }

    private fun opacityAlpha(prefs: SharedPreferences): Int {
        val pct = readInt(prefs, "widget_opacity", 100).coerceIn(60, 100)
        return pct * 255 / 100
    }

    // colores para los widgets de lista (superficie del tema)
    fun surface(context: Context, prefs: SharedPreferences): WidgetColors {
        val dark = isDark(context, prefs)
        val ink = if (dark) DARK_INK else LIGHT_INK
        return WidgetColors(
            background = if (dark) DARK_SURFACE else LIGHT_SURFACE,
            text = ink,
            subtext = ink and 0x00FFFFFF or (0xB3 shl 24),
            accent = ACCENT,
            alpha = opacityAlpha(prefs),
        )
    }

    // colores para el widget compacto (fondo tipo post-it, tinta oscura)
    fun postit(prefs: SharedPreferences): WidgetColors {
        val bg = parseColor(prefs.getString("widget_note_color", null), 0xFFFFE082.toInt())
        return WidgetColors(
            background = bg,
            text = LIGHT_INK,
            subtext = LIGHT_INK and 0x00FFFFFF or (0xB3 shl 24),
            accent = 0xFF8D5E00.toInt(),
            alpha = opacityAlpha(prefs),
        )
    }

    fun parseColor(hex: String?, fallback: Int): Int {
        if (hex.isNullOrBlank()) return fallback
        return try {
            Color.parseColor(hex)
        } catch (_: IllegalArgumentException) {
            fallback
        }
    }

    // home_widget puede guardar los números como Int o Long según la versión
    fun readInt(prefs: SharedPreferences, key: String, fallback: Int): Int {
        return when (val v = prefs.all[key]) {
            is Int -> v
            is Long -> v.toInt()
            is String -> v.toIntOrNull() ?: fallback
            else -> fallback
        }
    }
}
