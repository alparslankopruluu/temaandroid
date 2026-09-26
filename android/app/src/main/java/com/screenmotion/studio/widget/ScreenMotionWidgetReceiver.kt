package com.screenmotion.studio.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.screenmotion.studio.MainActivity
import com.screenmotion.studio.R
import com.screenmotion.studio.wallpaper.WallpaperSelection
import com.screenmotion.studio.model.Theme
import com.screenmotion.studio.model.SceneConfiguration
import com.screenmotion.studio.export.SceneBitmapRenderer
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.text.DateFormat
import java.util.Date

object WidgetSelection {
    private const val FILE = "screenmotion-widget"
    private const val THEME = "theme"
    private const val CONFIGURATION = "configuration"
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    fun save(context: Context, theme: Theme, configuration: SceneConfiguration) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putString(THEME, json.encodeToString(theme))
            .putString(CONFIGURATION, json.encodeToString(configuration))
            .apply()
    }

    fun load(context: Context): Pair<Theme, SceneConfiguration>? {
        val preferences = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val theme = preferences.getString(THEME, null) ?: return null
        return runCatching {
            val decodedTheme = json.decodeFromString<Theme>(theme)
            val configuration = preferences.getString(CONFIGURATION, null)
                ?.let { json.decodeFromString<SceneConfiguration>(it) } ?: SceneConfiguration()
            decodedTheme to configuration
        }.getOrNull()
    }
}

enum class WidgetStyle { PHOTO, DATE, CALENDAR, COLLECTION }

open class ScreenMotionWidgetReceiver : AppWidgetProvider() {
    protected open val style = WidgetStyle.PHOTO

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val selection = WidgetSelection.load(context) ?: WallpaperSelection.load(context)
            ids.forEach { id ->
                val views = RemoteViews(context.packageName, R.layout.widget_loading)
            selection?.let { (theme, configuration) ->
                val titleId = context.resources.getIdentifier(
                    theme.titleKey.replace(".", "_").replace("-", "_"),
                    "string",
                    context.packageName,
                )
                if (titleId != 0) views.setTextViewText(R.id.widget_title, context.getString(titleId))
                when (style) {
                    WidgetStyle.PHOTO -> views.setTextViewText(R.id.widget_subtitle, context.getString(R.string.widget_photo))
                    WidgetStyle.DATE -> {
                        views.setTextViewText(R.id.widget_title, DateFormat.getDateInstance(DateFormat.LONG).format(Date()))
                        views.setTextViewText(R.id.widget_subtitle, context.getString(R.string.widget_date))
                    }
                    WidgetStyle.CALENDAR -> {
                        views.setTextViewText(R.id.widget_title, DateFormat.getDateInstance(DateFormat.FULL).format(Date()))
                        views.setTextViewText(R.id.widget_subtitle, context.getString(R.string.widget_calendar))
                    }
                    WidgetStyle.COLLECTION -> {
                        val collectionId = context.resources.getIdentifier(
                            "collection_" + theme.collection.name.lowercase(), "string", context.packageName,
                        )
                        views.setTextViewText(R.id.widget_title, if (collectionId == 0) theme.collection.name else context.getString(collectionId))
                        views.setTextViewText(R.id.widget_subtitle, context.getString(R.string.widget_collection))
                    }
                }
                val snapshot = SceneBitmapRenderer.render(context, theme, configuration, 256, 256, 1.0)
                views.setImageViewBitmap(R.id.widget_artwork, snapshot)
                val intent = Intent(context, MainActivity::class.java).apply {
                    data = Uri.parse("screenmotion://theme/" + theme.id)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    PendingIntent.getActivity(
                        context,
                        id,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            manager.updateAppWidget(id, views)
        }
    }

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            listOf(
                ScreenMotionWidgetReceiver(), ScreenMotionDateWidgetReceiver(),
                ScreenMotionCalendarWidgetReceiver(), ScreenMotionCollectionWidgetReceiver(),
            ).forEach { receiver ->
                val component = ComponentName(context, receiver.javaClass)
                val ids = manager.getAppWidgetIds(component)
                if (ids.isNotEmpty()) receiver.onUpdate(context, manager, ids)
            }
        }
    }
}

class ScreenMotionDateWidgetReceiver : ScreenMotionWidgetReceiver() {
    override val style = WidgetStyle.DATE
}

class ScreenMotionCalendarWidgetReceiver : ScreenMotionWidgetReceiver() {
    override val style = WidgetStyle.CALENDAR
}

class ScreenMotionCollectionWidgetReceiver : ScreenMotionWidgetReceiver() {
    override val style = WidgetStyle.COLLECTION
}
