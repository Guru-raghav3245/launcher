package com.example.launcher

import android.app.Activity
import android.app.role.RoleManager
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.AlarmClock
import android.provider.MediaStore
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "yinyang.launcher/role"
private const val APP_CHANNEL = "yinyang.launcher/app"
private const val REQUEST_HOME_ROLE = 4242

/// Opens a system (or other app's) screen in its own task. Started plainly,
/// it would sit on top of this launcher in the launcher's task, so pressing
/// Home would bring that screen back instead of Home.
fun Activity.openExternal(intent: Intent) = startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private lateinit var appWidgetBridge: AppWidgetHostBridge
    private lateinit var calendarBridge: CalendarBridge
    private var appChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestHomeRole" -> requestHomeRole(result)
                "isDefaultLauncher" -> result.success(isDefaultLauncher())
                "defaultCommsPackages" -> result.success(defaultCommsPackages())
                "defaultDockPackages" -> result.success(defaultDockPackages())
                // Settings' system Home-app picker: lets the user switch to
                // *or away from* this launcher (requestHomeRole is a no-op
                // once the role is held).
                "openHomeSettings" -> {
                    openExternal(Intent(Settings.ACTION_HOME_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        appChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL)
        appChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                // Settings' "Restart Launcher": relaunch this activity in a fresh
                // task, then kill the process so all Dart/native state starts over.
                "restart" -> {
                    startActivity(Intent.makeRestartActivityTask(componentName))
                    result.success(null)
                    Runtime.getRuntime().exit(0)
                }
                // The App Drawer menu's "App info": the system page for one app.
                "openAppInfo" -> {
                    openExternal(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:${call.argument<String>("packageName")}"),
                        ),
                    )
                    result.success(null)
                }
                "setStatusBarVisible" -> {
                    setStatusBarVisible(call.argument<Boolean>("visible")!!)
                    result.success(null)
                }
                // Tapping Home's clock: the clock app's alarms screen. False if
                // no app handles it.
                "openClock" -> result.success(
                    try {
                        openExternal(Intent(AlarmClock.ACTION_SHOW_ALARMS))
                        true
                    } catch (_: ActivityNotFoundException) {
                        false
                    },
                )
                else -> result.notImplemented()
            }
        }
        appWidgetBridge = AppWidgetHostBridge(this)
        appWidgetBridge.attach(flutterEngine)
        UsageStatsBridge(this).attach(flutterEngine)
        MindfulTimerBridge(this).attach(flutterEngine)
        GesturesBridge(this).attach(flutterEngine)
        calendarBridge = CalendarBridge(this)
        calendarBridge.attach(flutterEngine)
        MusicBridge(this).attach(flutterEngine)
        registerReceiver(
            packagesReceiver,
            IntentFilter().apply {
                addAction(Intent.ACTION_PACKAGE_ADDED)
                addAction(Intent.ACTION_PACKAGE_REMOVED)
                addAction(Intent.ACTION_PACKAGE_CHANGED)
                addAction(Intent.ACTION_PACKAGE_REPLACED)
                addDataScheme("package")
            },
        )
    }

    // An app was installed, removed, updated, or enabled/disabled: Dart drops
    // its cached app list (InstalledAppsService.invalidate) and reloads.
    private val packagesReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            appChannel?.invokeMethod("packagesChanged", null)
        }
    }

    override fun onDestroy() {
        unregisterReceiver(packagesReceiver)
        super.onDestroy()
    }

    // Pressing Home while this launcher is already running (singleTop) lands
    // here: tell Dart to close sheets and return to the Home panel.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.hasCategory(Intent.CATEGORY_HOME)) appChannel?.invokeMethod("home", null)
    }

    override fun onStart() {
        super.onStart()
        appWidgetBridge.startListening()
    }

    override fun onStop() {
        appWidgetBridge.stopListening()
        super.onStop()
    }

    // Settings' "Status bar" switch (Phase 10 task 2). Through the window's
    // insets controller rather than Flutter's SystemChrome modes, which are
    // ignored for apps targeting API 36; a swipe from the top still shows the
    // bar briefly.
    private fun setStatusBarVisible(visible: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val controller = window.insetsController ?: return
            if (visible) {
                controller.show(WindowInsets.Type.statusBars())
            } else {
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                controller.hide(WindowInsets.Type.statusBars())
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = if (visible) 0 else View.SYSTEM_UI_FLAG_FULLSCREEN
        }
    }

    // Asks the package manager which activity currently handles HOME, which
    // works on every API level (RoleManager.isRoleHeld needs Q+).
    private fun isDefaultLauncher(): Boolean {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return packageManager.resolveActivity(home, 0)?.activityInfo?.packageName == packageName
    }

    // The default dialer and SMS apps (Focus Mode allows these out of the box).
    private fun defaultCommsPackages(): List<String> {
        val dialer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getSystemService(TelecomManager::class.java)?.defaultDialerPackage
        } else {
            null
        }
        return listOfNotNull(dialer, Telephony.Sms.getDefaultSmsPackage(this)).distinct()
    }

    // Home's dock defaults, in slot order: dialer, SMS, browser, camera. A
    // slot is null when nothing (or only the system chooser) handles it.
    private fun defaultDockPackages(): List<String?> {
        val dialer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getSystemService(TelecomManager::class.java)?.defaultDialerPackage
        } else {
            null
        }
        // With no default set, several handlers resolve to the system chooser
        // ("android"); then take the preinstalled one (e.g. the camera app,
        // not Snapchat, which also claims the camera intent).
        fun handler(intent: Intent) = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo?.packageName?.takeIf { it != "android" }
            ?: packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
                .firstOrNull { it.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0 }
                ?.activityInfo?.packageName
        return listOf(
            dialer,
            Telephony.Sms.getDefaultSmsPackage(this),
            handler(Intent(Intent.ACTION_VIEW, Uri.parse("https://"))),
            handler(Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)),
        )
    }

    // Returns true if the role is granted, false if the user cancelled the
    // system dialog, or null if this Android version has no ROLE_HOME (we
    // fall back to the Home-app settings screen, which reports no result).
    private fun requestHomeRole(result: MethodChannel.Result) {
        val roleManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            getSystemService(RoleManager::class.java)
        } else {
            null
        }

        if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
            if (roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                result.success(true)
                return
            }
            pendingResult = result
            startActivityForResult(roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME), REQUEST_HOME_ROLE)
        } else {
            openExternal(Intent(Settings.ACTION_HOME_SETTINGS))
            result.success(null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CALENDAR) {
            calendarBridge.onPermissionResult(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (appWidgetBridge.onActivityResult(requestCode, resultCode)) return
        if (requestCode == REQUEST_HOME_ROLE) {
            pendingResult?.success(resultCode == RESULT_OK)
            pendingResult = null
        }
    }
}
