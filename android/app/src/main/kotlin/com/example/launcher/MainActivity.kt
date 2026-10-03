package com.example.launcher

import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "yinyang.launcher/role"
private const val APP_CHANNEL = "yinyang.launcher/app"
private const val REQUEST_HOME_ROLE = 4242

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private lateinit var appWidgetBridge: AppWidgetHostBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestHomeRole" -> requestHomeRole(result)
                "isDefaultLauncher" -> result.success(isDefaultLauncher())
                "defaultCommsPackages" -> result.success(defaultCommsPackages())
                // Settings' system Home-app picker: lets the user switch to
                // *or away from* this launcher (requestHomeRole is a no-op
                // once the role is held).
                "openHomeSettings" -> {
                    startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // Settings' "Restart Launcher": relaunch this activity in a fresh task,
        // then kill the process so all Dart/native state starts over.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "restart") {
                startActivity(Intent.makeRestartActivityTask(componentName))
                result.success(null)
                Runtime.getRuntime().exit(0)
            } else {
                result.notImplemented()
            }
        }
        appWidgetBridge = AppWidgetHostBridge(this)
        appWidgetBridge.attach(flutterEngine)
        UsageStatsBridge(this).attach(flutterEngine)
        MindfulTimerBridge(this).attach(flutterEngine)
    }

    override fun onStart() {
        super.onStart()
        appWidgetBridge.startListening()
    }

    override fun onStop() {
        appWidgetBridge.stopListening()
        super.onStop()
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
            startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
            result.success(null)
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
