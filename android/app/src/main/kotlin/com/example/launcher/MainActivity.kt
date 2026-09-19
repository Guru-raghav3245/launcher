package com.example.launcher

import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "yinyang.launcher/role"
private const val REQUEST_HOME_ROLE = 4242

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private lateinit var appWidgetBridge: AppWidgetHostBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "requestHomeRole") {
                requestHomeRole(result)
            } else {
                result.notImplemented()
            }
        }
        appWidgetBridge = AppWidgetHostBridge(this)
        appWidgetBridge.attach(flutterEngine)
        UsageStatsBridge(this).attach(flutterEngine)
    }

    override fun onStart() {
        super.onStart()
        appWidgetBridge.startListening()
    }

    override fun onStop() {
        appWidgetBridge.stopListening()
        super.onStop()
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
