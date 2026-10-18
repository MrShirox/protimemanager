package com.example.protimemanager

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class WorkWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val snapshot = try { JSONObject(data.getString("work_snapshot", "{}") ?: "{}") } catch (_: Exception) { JSONObject() }
        val active = snapshot.optBoolean("active", false)
        fun time(key: String): String = if (snapshot.isNull(key)) "—" else
            SimpleDateFormat("dd/MM HH:mm", Locale.FRANCE).format(Date(snapshot.optLong(key)))
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.work_widget)
            val error = data.getString("work_error", "") ?: ""
            views.setTextViewText(R.id.work_status, if (error.isNotEmpty()) error else
                if (active) "Début : ${time("start")}" else "Fin : ${time("end")}")
            views.setTextViewText(R.id.work_pause_status, if (active && !snapshot.isNull("pauseEnd"))
                "Reprise automatique : ${time("pauseEnd")}" else "Pause déduite du temps travaillé")
            views.setOnClickPendingIntent(R.id.work_title,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            fun action(view: Int, query: String) {
                views.setOnClickPendingIntent(view, HomeWidgetBackgroundIntent.getBroadcast(context,
                    Uri.parse("protime://work?$query")))
            }
            action(R.id.work_start, "action=start")
            action(R.id.work_stop, "action=stop")
            for ((view, minutes) in listOf(R.id.pause20 to 20, R.id.pause30 to 30,
                R.id.pause45 to 45, R.id.pause50 to 50, R.id.pause60 to 60)) {
                action(view, "action=pause&minutes=$minutes")
                views.setBoolean(view, "setEnabled", active)
            }
            views.setBoolean(R.id.work_start, "setEnabled", !active)
            views.setBoolean(R.id.work_stop, "setEnabled", active)
            manager.updateAppWidget(id, views)
        }
    }
}
