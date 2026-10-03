package com.example.launcher

import android.accessibilityservice.AccessibilityService
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "yinyang.launcher/gestures"

/// Home's configurable gestures (Phase 8 task 7), done the way the original
/// Yin Yang Launcher does them: swipe down can open the notification shade
/// (hidden StatusBarManager call, EXPAND_STATUS_BAR is granted at install),
/// and double tap can lock the screen via LockAccessibilityService
/// (recommended) or device admin (legacy).
class GesturesBridge(private val activity: MainActivity) {
    private val admin = ComponentName(activity, LockAdminReceiver::class.java)
    private val policy get() = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    fun attach(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "expandNotifications" -> result.success(expandNotifications())
                "accessibilityLockReady" -> result.success(LockAccessibilityService.instance != null)
                "openAccessibilitySettings" -> {
                    activity.openExternal(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "lockWithAccessibility" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                        LockAccessibilityService.instance
                            ?.performGlobalAction(AccessibilityService.GLOBAL_ACTION_LOCK_SCREEN) == true,
                )
                "deviceAdminReady" -> result.success(policy.isAdminActive(admin))
                "requestDeviceAdmin" -> {
                    // Not openExternal: Settings refuses ADD_DEVICE_ADMIN as a new
                    // task. It's a dialog that closes itself, so it can't strand
                    // itself on top of Home.
                    activity.startActivity(
                        Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                            .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, admin)
                            .putExtra(
                                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                activity.getString(R.string.lock_device_admin_description),
                            ),
                    )
                    result.success(null)
                }
                "lockWithDeviceAdmin" -> result.success(
                    policy.isAdminActive(admin).also { if (it) policy.lockNow() },
                )
                else -> result.notImplemented()
            }
        }
    }

    // No public API opens the shade; StatusBarManager.expandNotificationsPanel
    // is hidden but stable, and what launchers (the original included) use.
    @Suppress("WrongConstant")
    private fun expandNotifications(): Boolean = try {
        val statusBar = activity.getSystemService("statusbar")
        statusBar.javaClass.getMethod("expandNotificationsPanel").invoke(statusBar)
        true
    } catch (_: Exception) {
        false
    }
}
