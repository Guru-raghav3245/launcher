package com.example.launcher

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "student.launcher/calendar"
const val REQUEST_CALENDAR = 4343

/// The Calendar tile's data (Phase 9 task 5): upcoming event instances from
/// CalendarContract, plus the READ_CALENDAR runtime permission. The first
/// request shows Android's dialog; once the user has said no for good
/// (Android won't show it again), the request opens this app's settings page.
class CalendarBridge(private val activity: MainActivity) {
    private var pendingRequest: MethodChannel.Result? = null
    private val prefs get() = activity.getSharedPreferences("calendar_bridge", Context.MODE_PRIVATE)

    fun attach(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(hasAccess())
                "requestAccess" -> requestAccess(result)
                "events" -> {
                    val days = call.argument<Int>("days")!!
                    activity.inBackground(result) { if (hasAccess()) events(days) else emptyList<Any>() }
                }
                "openEvent" -> {
                    val id = (call.argument<Number>("id"))!!.toLong()
                    activity.openExternal(
                        Intent(Intent.ACTION_VIEW, ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id)),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Once granted, forget that we asked: if the user later revokes it in
    // Settings, the next request should show the dialog again rather than
    // being mistaken for "denied for good".
    private fun hasAccess(): Boolean {
        val granted = activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
        if (granted) prefs.edit().putBoolean("asked", false).apply()
        return granted
    }

    private fun requestAccess(result: MethodChannel.Result) {
        if (hasAccess()) return result.success(true)
        val askedBefore = prefs.getBoolean("asked", false)
        if (askedBefore && !activity.shouldShowRequestPermissionRationale(Manifest.permission.READ_CALENDAR)) {
            // Denied for good: only the settings page can turn it on now.
            activity.openExternal(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}")))
            return result.success(false)
        }
        prefs.edit().putBoolean("asked", true).apply()
        pendingRequest = result
        activity.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), REQUEST_CALENDAR)
    }

    /// Called from MainActivity.onRequestPermissionsResult.
    fun onPermissionResult(granted: Boolean) {
        pendingRequest?.success(granted)
        pendingRequest = null
    }

    // Event instances (so repeating events appear on each day) from now to
    // [days] ahead, in visible calendars, soonest first.
    private fun events(days: Int): List<Map<String, Any?>> {
        val now = System.currentTimeMillis()
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon()
            .also { ContentUris.appendId(it, now) }
            .also { ContentUris.appendId(it, now + days * 86_400_000L) }
            .build()
        val columns = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.ALL_DAY,
        )
        val result = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(
            uri,
            columns,
            "${CalendarContract.Instances.VISIBLE} = 1",
            null,
            "${CalendarContract.Instances.BEGIN} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                result.add(
                    mapOf(
                        "id" to cursor.getLong(0),
                        "title" to cursor.getString(1),
                        "begin" to cursor.getLong(2),
                        "end" to cursor.getLong(3),
                        "allDay" to (cursor.getInt(4) == 1),
                    ),
                )
            }
        }
        return result
    }
}
