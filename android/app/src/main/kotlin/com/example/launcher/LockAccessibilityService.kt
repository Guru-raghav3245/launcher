package com.example.launcher

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/// Double-tap-to-lock (Phase 8 task 7), like the original's
/// AccessibilityLockService: it reads no events or screen content (see
/// res/xml/lock_accessibility_service.xml) and only ever performs
/// GLOBAL_ACTION_LOCK_SCREEN, which keeps fingerprint/face unlock working.
class LockAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        instance = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    companion object {
        /// The running service while the user has it switched on.
        var instance: LockAccessibilityService? = null
    }
}
