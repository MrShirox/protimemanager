package com.example.protimemanager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "protimemanager/reminders")
            .setMethodCallHandler { call, result ->
                if (call.method == "repairScheduledStore") {
                    result.success(repairScheduledStore(call.argument<Boolean>("force") == true))
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * flutter_local_notifications keeps its scheduled reminders as JSON. Builds
     * made before proguard-rules.pro saved it with obfuscated field names, which
     * the plugin can no longer read and then fails on every scheduling call.
     * Returns true when that unreadable list was cleared.
     */
    private fun repairScheduledStore(force: Boolean): Boolean {
        val prefs = getSharedPreferences("scheduled_notifications", MODE_PRIVATE)
        val json = prefs.getString("scheduled_notifications", null) ?: return false
        val readable = !force && try {
            val items = JSONArray(json)
            (0 until items.length()).all { items.getJSONObject(it).has("id") }
        } catch (_: Exception) {
            false
        }
        if (readable) return false
        prefs.edit().remove("scheduled_notifications").commit()
        return true
    }
}
