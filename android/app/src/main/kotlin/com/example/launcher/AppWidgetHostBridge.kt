package com.example.launcher

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import android.widget.RemoteViews
import java.io.ByteArrayOutputStream
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
                "preview" -> result.success(preview(call.argument<String>("provider")!!))
                "aspect" -> result.success(aspect(call.argument<Int>("widgetId")!!))
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

    // Height over width of a bound widget as its provider designed it (cells
    // when declared, else its minimum size), so My Space can give its tile the
    // same proportions. Null if the id isn't bound.
    private fun aspect(widgetId: Int): Double? {
        val info = manager.getAppWidgetInfo(widgetId) ?: return null
        val cells = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && info.targetCellWidth > 0 && info.targetCellHeight > 0
        val width = if (cells) info.targetCellWidth else info.minWidth
        val height = if (cells) info.targetCellHeight else info.minHeight
        return if (width > 0 && height > 0) height.toDouble() / width else null
    }

    // A picture of a provider's widget for the Add New Tile sheet and Manage
    // tiles (Phase 12 task 6), as a PNG at most 600 px wide: its preview
    // layout (Android 12+) drawn off screen, else its preview image, else its
    // icon. Null if it has none of those.
    private fun preview(provider: String): ByteArray? {
        val component = ComponentName.unflattenFromString(provider) ?: return null
        val info = manager.installedProviders.firstOrNull { it.provider == component } ?: return null
        val bitmap = runCatching { renderPreviewLayout(info) }.getOrNull()
            ?: runCatching { info.loadPreviewImage(activity, 0)?.toBitmap() }.getOrNull()
            ?: runCatching { info.loadIcon(activity, 0)?.toBitmap() }.getOrNull()
            ?: return null
        val scale = minOf(1f, 600f / bitmap.width)
        val scaled = if (scale < 1f) {
            Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true)
        } else {
            bitmap
        }
        return ByteArrayOutputStream().also { scaled.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    }

    // Inflates the provider's preview layout like a host would show it, at
    // its target width in cells (about 74 dp each), or its minimum width; it
    // gets its target height or the height its content needs, whichever is
    // taller (Spotify's declares less than its layout uses, which clipped it).
    private fun renderPreviewLayout(info: AppWidgetProviderInfo): Bitmap? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || info.previewLayout == 0) return null
        val density = activity.resources.displayMetrics.density
        val maxWidth = activity.resources.displayMetrics.widthPixels - (32 * density).toInt()
        val cell = 74 * density
        val width = (if (info.targetCellWidth > 0) (info.targetCellWidth * cell).toInt() else info.minWidth)
            .coerceIn((80 * density).toInt(), maxWidth)
        val target = if (info.targetCellHeight > 0) (info.targetCellHeight * cell).toInt() else info.minHeight
        val view = RemoteViews(info.provider.packageName, info.previewLayout).apply(activity, FrameLayout(activity))
        view.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        val height = maxOf(target, view.measuredHeight).coerceIn((40 * density).toInt(), (400 * density).toInt())
        view.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY),
        )
        view.layout(0, 0, width, height)
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { view.draw(Canvas(it)) }
    }

    private fun Drawable.toBitmap(): Bitmap {
        val width = intrinsicWidth.takeIf { it > 0 } ?: 200
        val height = intrinsicHeight.takeIf { it > 0 } ?: 200
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also {
            setBounds(0, 0, width, height)
            draw(Canvas(it))
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
