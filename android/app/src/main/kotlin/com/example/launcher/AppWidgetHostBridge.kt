package com.example.launcher

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.ViewTreeObserver
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

private const val HOST_ID = 4243
private const val CHANNEL = "student.launcher/appwidget"
private const val VIEW_TYPE = "student.launcher/appwidget_view"
const val REQUEST_BIND_WIDGET = 4244

/// Embeds other apps' native Android AppWidgets in My Space (Phase 3 task
/// 7), via AppWidgetHost/AppWidgetManager. Binding a widget for an app that
/// isn't the default launcher isn't auto-granted, so [bind] falls back to
/// the system's ACTION_APPWIDGET_BIND consent dialog when the fast path is
/// refused — the same two-step flow every third-party launcher uses.
class AppWidgetHostBridge(private val activity: MainActivity) {
    private val host = AppWidgetHost(activity, HOST_ID)
    private val manager = AppWidgetManager.getInstance(activity)
    private var pendingBind: MethodChannel.Result? = null

    fun attach(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "listProviders" -> result.success(listProviders())
                "allocateId" -> result.success(host.allocateAppWidgetId())
                "bind" -> bind(
                    call.argument<Int>("widgetId")!!,
                    call.argument<String>("provider")!!,
                    result,
                )
                "deleteId" -> {
                    host.deleteAppWidgetId(call.argument<Int>("widgetId")!!)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        flutterEngine.platformViewsController.registry.registerViewFactory(
            VIEW_TYPE,
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    val widgetId = (args as? Map<*, *>)?.get("widgetId") as? Int ?: -1
                    return AppWidgetPlatformView(context, host, manager, widgetId)
                }
            },
        )
    }

    @Suppress("DEPRECATION") // info.label needs no PackageManager/context round trip.
    private fun listProviders(): List<Map<String, Any?>> {
        return manager.installedProviders.map { info ->
            mapOf(
                "provider" to info.provider.flattenToString(),
                "packageName" to info.provider.packageName,
                "label" to info.label,
            )
        }
    }

    private fun bind(widgetId: Int, provider: String, result: MethodChannel.Result) {
        val component = ComponentName.unflattenFromString(provider)!!
        if (manager.bindAppWidgetIdIfAllowed(widgetId, component)) {
            result.success(true)
            return
        }
        pendingBind = result
        val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, component)
        }
        activity.startActivityForResult(intent, REQUEST_BIND_WIDGET)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_BIND_WIDGET) return false
        pendingBind?.success(resultCode == Activity.RESULT_OK)
        pendingBind = null
        return true
    }

    fun startListening() = host.startListening()
    fun stopListening() = host.stopListening()
}

@Suppress("DEPRECATION") // 5-arg updateAppWidgetSize keeps this working pre-API 31.
private class AppWidgetPlatformView(
    context: Context,
    host: AppWidgetHost,
    manager: AppWidgetManager,
    widgetId: Int,
) : PlatformView {
    private val hostView: AppWidgetHostView = manager.getAppWidgetInfo(widgetId)?.let { info ->
        host.createView(context, widgetId, info)
    } ?: AppWidgetHostView(context)

    init {
        // Many widgets pick their RemoteViews layout by declared size and
        // render blank at the 0x0 dp default; tell the widget its real size
        // once Flutter's AndroidView has laid it out.
        hostView.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                val width = hostView.width
                val height = hostView.height
                if (width <= 0 || height <= 0) return
                val density = hostView.resources.displayMetrics.density
                val widthDp = (width / density).toInt()
                val heightDp = (height / density).toInt()
                hostView.updateAppWidgetSize(Bundle(), widthDp, heightDp, widthDp, heightDp)
                hostView.viewTreeObserver.removeOnGlobalLayoutListener(this)
            }
        })
    }

    override fun getView(): View = hostView

    override fun dispose() {}
}
