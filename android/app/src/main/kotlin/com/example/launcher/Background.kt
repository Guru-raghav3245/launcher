package com.example.launcher

import io.flutter.plugin.common.MethodChannel

/// Runs [work] off the main thread and hands its value (or its error) to
/// [result] back on it. Anything that queries Android's stats or content
/// providers goes through here: on the main thread it would hold up the
/// launcher's first frames as it comes back from an app, which is exactly
/// when Mind Space, the drawer and the tiles all refresh.
fun MainActivity.inBackground(result: MethodChannel.Result, work: () -> Any?) {
    Thread {
        val value = runCatching(work)
        runOnUiThread { value.fold({ result.success(it) }, { result.error("failed", it.message, null) }) }
    }.start()
}
