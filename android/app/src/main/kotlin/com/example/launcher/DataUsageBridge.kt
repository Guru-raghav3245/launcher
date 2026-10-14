package com.example.launcher

import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.net.ConnectivityManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "student.launcher/datausage"

/// The Data Usage tile's numbers (`NetworkStatsManager`): bytes over mobile
/// data and Wi-Fi between two times, for the whole phone and per app. It
/// rides on the usage-access grant Mind Space already asks for.
class DataUsageBridge(private val activity: MainActivity) {
    fun attach(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "usage" -> Thread {
                    val value = runCatching {
                        usage(call.argument<Long>("start")!!, call.argument<Long>("end")!!, call.argument<Int>("topApps")!!)
                    }
                    activity.runOnUiThread {
                        value.fold({ result.success(it) }, { result.error("usage", it.message, null) })
                    }
                }.start()
                else -> result.notImplemented()
            }
        }
    }

    // {mobile, wifi, apps: [{package, mobile, wifi}]} in bytes, apps being the
    // [topApps] biggest by total (none when 0).
    private fun usage(start: Long, end: Long, topApps: Int): Map<String, Any> {
        val manager = activity.getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val mobile = totals(manager, ConnectivityManager.TYPE_MOBILE, start, end)
        val wifi = totals(manager, ConnectivityManager.TYPE_WIFI, start, end)
        val apps = if (topApps <= 0) emptyList() else {
            val byUid = HashMap<Int, LongArray>() // uid -> [mobile, wifi]
            for ((index, type) in listOf(ConnectivityManager.TYPE_MOBILE, ConnectivityManager.TYPE_WIFI).withIndex()) {
                val stats = runCatching { manager.querySummary(type, null, start, end) }.getOrNull() ?: continue
                val bucket = NetworkStats.Bucket()
                while (stats.hasNextBucket()) {
                    stats.getNextBucket(bucket)
                    byUid.getOrPut(bucket.uid) { LongArray(2) }[index] += bucket.rxBytes + bucket.txBytes
                }
                stats.close()
            }
            val pm = activity.packageManager
            // Apps sharing a uid are one row, named after the first launchable one.
            byUid.entries
                .sortedByDescending { it.value[0] + it.value[1] }
                .mapNotNull { (uid, bytes) ->
                    val pkg = pm.getPackagesForUid(uid)?.firstOrNull { pm.getLaunchIntentForPackage(it) != null }
                    pkg?.let { mapOf("package" to it, "mobile" to bytes[0], "wifi" to bytes[1]) }
                }
                .take(topApps)
        }
        return mapOf("mobile" to mobile, "wifi" to wifi, "apps" to apps)
    }

    private fun totals(manager: NetworkStatsManager, type: Int, start: Long, end: Long): Long {
        val bucket = runCatching { manager.querySummaryForDevice(type, null, start, end) }
            .onFailure { android.util.Log.w("DataUsage", "device totals for type $type failed", it) }
            .getOrNull() ?: return 0
        return bucket.rxBytes + bucket.txBytes
    }
}
