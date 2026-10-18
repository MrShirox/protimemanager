package com.example.protimemanager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Native widget: actions are written straight to the app's SQLite database.
 * No background Flutter engine is started, so a tap can never crash the app
 * and the widget updates instantly. The app reloads the database on resume.
 */
class WorkWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "WorkWidget"
        private const val ACTION_START = "com.example.protimemanager.widget.START"
        private const val ACTION_STOP = "com.example.protimemanager.widget.STOP"
        private const val ACTION_PAUSE = "com.example.protimemanager.widget.PAUSE"
        private const val EXTRA_MINUTES = "minutes"
        private const val PREFS = "work_widget"
        private const val ERROR_TTL_MS = 2 * 60 * 1000L

        private val PAUSE_BUTTONS = listOf(
            R.id.pause20 to 20, R.id.pause30 to 30, R.id.pause45 to 45,
            R.id.pause50 to 50, R.id.pause60 to 60
        )

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, WorkWidgetProvider::class.java))
            render(context, manager, ids)
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            if (ids.isEmpty()) return
            val views = try {
                buildViews(context)
            } catch (e: Throwable) {
                Log.e(TAG, "Widget render failed", e)
                fallbackViews(context)
            }
            for (id in ids) {
                try {
                    manager.updateAppWidget(id, views)
                } catch (e: Throwable) {
                    Log.e(TAG, "Widget update failed", e)
                }
            }
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = baseViews(context)
            val now = System.currentTimeMillis()
            val state = try {
                WorkWidgetStore(context).snapshot()
            } catch (e: WidgetException) {
                showError(views, e.message)
                return views
            }
            val active = state.active
            val paused = active?.pausedAt(now) == true
            val worked = when {
                active != null -> active.worked(now)
                state.last != null -> state.last.worked(now)
                else -> 0L
            }

            views.setChronometer(R.id.work_chrono, SystemClock.elapsedRealtime() - worked,
                null, active != null && !paused)

            when {
                active == null -> {
                    views.setTextViewText(R.id.work_state, "ARRÊTÉ")
                    views.setTextColor(R.id.work_dot, 0xFF90A4AE.toInt())
                    views.setTextViewText(R.id.work_detail, state.last?.let {
                        "Dernière : ${fmtDay(it.start)} ${fmtTime(it.start)} → ${fmtTime(it.end ?: now)}"
                    } ?: "Appuie sur Démarrer pour lancer la journée")
                }
                paused -> {
                    views.setTextViewText(R.id.work_state, "EN PAUSE")
                    views.setTextColor(R.id.work_dot, 0xFFFFB74D.toInt())
                    val resume = active.pauses.lastOrNull { it.deduction == null && it.end != null && it.end > now }
                    views.setTextViewText(R.id.work_detail,
                        if (resume != null) "Reprise à ${fmtTime(resume.end!!)}" else "Pause en cours")
                }
                else -> {
                    views.setTextViewText(R.id.work_state, "EN COURS")
                    views.setTextColor(R.id.work_dot, 0xFF4CD08A.toInt())
                    val deducted = active.deductedMinutes()
                    views.setTextViewText(R.id.work_detail, "Début ${fmtTime(active.start)}" +
                        if (deducted > 0) "  ·  pause −${fmtMinutes(deducted)}" else "")
                }
            }

            views.setViewVisibility(R.id.work_start, if (active == null) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.work_stop, if (active != null) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.work_pauses, if (active != null && !paused) View.VISIBLE else View.GONE)

            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val error = prefs.getString("error", null)
            if (!error.isNullOrEmpty() && now - prefs.getLong("errorAt", 0) < ERROR_TTL_MS) {
                views.setTextViewText(R.id.work_error, error)
                views.setViewVisibility(R.id.work_error, View.VISIBLE)
            }
            return views
        }

        private fun baseViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.work_widget)
            views.setOnClickPendingIntent(R.id.work_header, openApp(context))
            views.setOnClickPendingIntent(R.id.work_chrono, openApp(context))
            views.setOnClickPendingIntent(R.id.work_start, broadcast(context, ACTION_START, 0, 1))
            views.setOnClickPendingIntent(R.id.work_stop, broadcast(context, ACTION_STOP, 0, 2))
            for ((view, minutes) in PAUSE_BUTTONS) {
                views.setOnClickPendingIntent(view, broadcast(context, ACTION_PAUSE, minutes, 100 + minutes))
            }
            views.setViewVisibility(R.id.work_error, View.GONE)
            return views
        }

        private fun showError(views: RemoteViews, message: String?) {
            views.setTextViewText(R.id.work_state, "PROTIMEMANAGER")
            views.setTextColor(R.id.work_dot, 0xFF90A4AE.toInt())
            views.setChronometer(R.id.work_chrono, SystemClock.elapsedRealtime(), null, false)
            views.setTextViewText(R.id.work_detail, message ?: "Ouvre ProTimeManager")
            views.setViewVisibility(R.id.work_start, View.GONE)
            views.setViewVisibility(R.id.work_stop, View.GONE)
            views.setViewVisibility(R.id.work_pauses, View.GONE)
        }

        private fun fallbackViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.work_widget)
            views.setOnClickPendingIntent(R.id.work_header, openApp(context))
            showError(views, "Touchez pour ouvrir ProTimeManager")
            return views
        }

        private fun openApp(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            return PendingIntent.getActivity(context, 0, intent, pendingFlags())
        }

        private fun broadcast(context: Context, action: String, minutes: Int, requestCode: Int): PendingIntent {
            val intent = Intent(context, WorkWidgetProvider::class.java)
                .setAction(action)
                .putExtra(EXTRA_MINUTES, minutes)
            return PendingIntent.getBroadcast(context, requestCode, intent, pendingFlags())
        }

        private fun pendingFlags(): Int = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)

        private fun fmtTime(ms: Long) = SimpleDateFormat("HH:mm", Locale.FRANCE).format(Date(ms))
        private fun fmtDay(ms: Long) = SimpleDateFormat("dd/MM", Locale.FRANCE).format(Date(ms))
        private fun fmtMinutes(m: Int) = if (m < 60) "$m min" else "${m / 60} h ${"%02d".format(m % 60)}"
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != ACTION_START && action != ACTION_STOP && action != ACTION_PAUSE) {
            try {
                super.onReceive(context, intent)
            } catch (e: Throwable) {
                Log.e(TAG, "Widget broadcast failed", e)
            }
            return
        }
        val pending = goAsync()
        Thread {
            try {
                val error = try {
                    val store = WorkWidgetStore(context)
                    when (action) {
                        ACTION_START -> store.start()
                        ACTION_STOP -> store.stop()
                        else -> store.pause(intent.getIntExtra(EXTRA_MINUTES, 0))
                    }
                    null
                } catch (e: WidgetException) {
                    e.message
                } catch (e: Throwable) {
                    Log.e(TAG, "Widget action failed", e)
                    "Action non enregistrée. Ouvre ProTimeManager."
                }
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putString("error", error ?: "")
                    .putLong("errorAt", System.currentTimeMillis())
                    .apply()
                refreshAll(context)
            } catch (e: Throwable) {
                Log.e(TAG, "Widget refresh failed", e)
            } finally {
                pending.finish()
            }
        }.start()
    }
}
