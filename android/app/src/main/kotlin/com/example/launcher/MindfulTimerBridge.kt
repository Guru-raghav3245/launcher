package com.example.launcher

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "student.launcher/timer"

/// Mindful Timer's session timer (Phase 7 task 6), modelled on the original
/// Yin Yang Launcher: the countdown lives in this (HOME, so long-lived)
/// process, and when it ends while the timed app is still in front, a
/// "Time's up" screen is drawn over it via SYSTEM_ALERT_WINDOW.
// ponytail: an in-process Handler, so the overlay is missed if Android kills
// the launcher mid-session; a foreground service fixes that at the cost of a
// permanent notification.
class MindfulTimerBridge(private val activity: MainActivity) {
    private val handler = Handler(Looper.getMainLooper())
    private val windowManager = activity.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var overlay: View? = null

    fun attach(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> result.success(canDrawOverlays())
                "requestOverlay" -> {
                    activity.openExternal(
                        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${activity.packageName}")),
                    )
                    result.success(null)
                }
                "startSession" -> {
                    startSession(
                        call.argument<String>("packageName")!!,
                        call.argument<String>("appName")!!,
                        call.argument<Int>("minutes")!!,
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canDrawOverlays() =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(activity)

    // One session at a time: a new one replaces any pending timer.
    private fun startSession(packageName: String, appName: String, minutes: Int) {
        handler.removeCallbacksAndMessages(null)
        val startedAt = System.currentTimeMillis()
        handler.postDelayed({
            if (foregroundPackage(startedAt) == packageName) showTimesUp(appName, minutes)
        }, minutes * 60_000L)
    }

    // The package of the most recent foreground move since the session began.
    @Suppress("DEPRECATION") // MOVE_TO_FOREGROUND aliases ACTIVITY_RESUMED.
    private fun foregroundPackage(since: Long): String? {
        val usm = activity.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(since - 10_000, System.currentTimeMillis())
        val event = UsageEvents.Event()
        var latest: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) latest = event.packageName
        }
        return latest
    }

    private fun showTimesUp(appName: String, minutes: Int) {
        if (overlay != null || !canDrawOverlays()) return
        val dark = activity.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.settings_is_dark", false)
        val ink = if (dark) 0xFFFFFFFF.toInt() else 0xFF000000.toInt()
        val paper = if (dark) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()
        val secondary = if (dark) 0x99FFFFFF.toInt() else 0x8A000000.toInt()
        val dp = activity.resources.displayMetrics.density

        fun text(value: String, size: Float, color: Int, bold: Boolean = false) = TextView(activity).apply {
            text = value
            textSize = size
            setTextColor(color)
            gravity = Gravity.CENTER
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }

        val view = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(paper)
            val pad = (32 * dp).toInt()
            setPadding(pad, pad, pad, pad)
            addView(text("Time's up!", 32f, ink, bold = true))
            addView(text("You set $minutes min on $appName", 16f, secondary).apply {
                setPadding(0, (8 * dp).toInt(), 0, (40 * dp).toInt())
            })
            addView(Button(activity).apply {
                text = "Go Home"
                isAllCaps = false
                textSize = 16f
                setTextColor(paper)
                background = GradientDrawable().apply {
                    setColor(ink)
                    cornerRadius = 12 * dp
                }
                setOnClickListener { goHome() }
            }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (52 * dp).toInt()))
        }

        @Suppress("DEPRECATION")
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        windowManager.addView(
            view,
            WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                type,
                0,
                PixelFormat.OPAQUE,
            ),
        )
        overlay = view
    }

    private fun goHome() {
        overlay?.let(windowManager::removeView)
        overlay = null
        activity.startActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
