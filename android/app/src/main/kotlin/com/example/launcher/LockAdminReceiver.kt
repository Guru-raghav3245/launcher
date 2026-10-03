package com.example.launcher

import android.app.admin.DeviceAdminReceiver

/// Double-tap-to-lock's legacy method (Phase 8 task 7): device admin with
/// only the force-lock policy. DevicePolicyManager.lockNow() makes the next
/// unlock need the PIN/pattern rather than fingerprint.
class LockAdminReceiver : DeviceAdminReceiver()
