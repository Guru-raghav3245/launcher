package com.example.launcher

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "yinyang.launcher/usage"

/// Wraps Android's UsageStatsManager for Mind Space (Phase 4 task 1).
/// PACKAGE_USAGE_STATS is a "special" permission: it can't be requested via
/// a runtime dialog, only granted by the user in
/// Settings.ACTION_USAGE_ACCESS_SETTINGS, and its grant state is read back
/// via AppOpsManager rather than checkSelfPermission. There's no
/// startActivityForResult callback for that settings screen, so
/// [hasAccess] is meant to be re-checked whenever the app resumes.
class UsageStatsBridge(private val activity: MainActivity) {
    fun attach(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(hasAccess())
                "requestAccess" -> {
                    activity.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "queryEvents" -> result.success(
                    queryEvents(call.argument<Long>("start")!!, call.argument<Long>("end")!!),
                )
                "lastUsed" -> result.success(lastUsed(call.argument<Long>("start")!!, call.argument<Long>("end")!!))
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAccess(): Boolean {
        val appOps = activity.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            activity.packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // Returns raw foreground/background/keyguard-hidden events in [start, end)
    // (epoch millis) as {"packageName", "type", "timestamp"} maps — the
    // building block tasks 3-5 derive the hourly chart, per-app time, and
    // unlock-habit detection from, so this stays a thin, ungrouped feed
    // rather than guessing at aggregations those tasks haven't asked for
    // yet.
    @Suppress("DEPRECATION") // MOVE_TO_* aliases the API 29+ names, works down to our minSdk.
    private fun queryEvents(start: Long, end: Long): List<Map<String, Any?>> {
        val usageStatsManager = activity.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usageStatsManager.queryEvents(start, end)
        val result = mutableListOf<Map<String, Any?>>()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val type = when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> "foreground"
                UsageEvents.Event.MOVE_TO_BACKGROUND -> "background"
                UsageEvents.Event.KEYGUARD_HIDDEN -> "unlocked"
                else -> null
            } ?: continue
            result.add(mapOf("packageName" to event.packageName, "type" to type, "timestamp" to event.timeStamp))
        }
        return result
    }

    // Each package's last foreground time (epoch millis) in [start, end),
    // from the aggregated daily stats, which Android keeps far longer than
    // raw events: the drawer's recent apps and its 30-day unused filter
    // (Phase 8 task 5). This launcher itself is left out.
    private fun lastUsed(start: Long, end: Long): Map<String, Long> {
        val usageStatsManager = activity.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        return usageStatsManager.queryAndAggregateUsageStats(start, end)
            .filter { (pkg, stats) -> pkg != activity.packageName && stats.lastTimeUsed > 0 }
            .mapValues { it.value.lastTimeUsed }
    }
}
