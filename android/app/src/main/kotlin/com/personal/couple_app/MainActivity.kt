package com.personal.couple_app

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val WIDGET_ROUTE_CHANNEL = "com.personal.couple_app/widget_route"
        private const val DEVICE_SETTINGS_CHANNEL = "com.personal.couple_app/device_settings"
        const val EXTRA_WIDGET_ROUTE = "widget_route"
    }

    private var routeChannel: MethodChannel? = null
    private var pendingInitialRoute: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingInitialRoute = extractWidgetRoute(intent)

        routeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_ROUTE_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getInitialRoute") {
                    val route = pendingInitialRoute
                    pendingInitialRoute = null
                    result.success(route)
                } else {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_SETTINGS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && pm != null) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(ignoring)
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } else {
                            openAppDetailsSettings()
                        }
                        result.success(true)
                    } catch (_: Throwable) {
                        try {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(true)
                        } catch (_: Throwable) {
                            openAppDetailsSettings()
                            result.success(false)
                        }
                    }
                }
                "openExactAlarmSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } else {
                            openAppDetailsSettings()
                        }
                        result.success(true)
                    } catch (_: Throwable) {
                        openAppDetailsSettings()
                        result.success(false)
                    }
                }
                "saveImageToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "couple_drawing_${System.currentTimeMillis()}.png"
                    if (bytes == null || bytes.isEmpty()) {
                        result.success(false)
                    } else {
                        Thread {
                            val saved = savePngToMediaStore(bytes, fileName)
                            runOnUiThread { result.success(saved) }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun savePngToMediaStore(bytes: ByteArray, fileName: String): Boolean {
        var insertedUri: Uri? = null
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/CoupleApp")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: return false
            insertedUri = uri
            val wrote = contentResolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
                true
            } ?: false
            if (!wrote) {
                try { contentResolver.delete(uri, null, null) } catch (_: Throwable) {}
                return false
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            }
            true
        } catch (_: Throwable) {
            insertedUri?.let { uri ->
                try { contentResolver.delete(uri, null, null) } catch (_: Throwable) {}
            }
            false
        }
    }

    private fun openAppDetailsSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
            }
            startActivity(intent)
        } catch (_: Throwable) {
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = extractWidgetRoute(intent)
        if (!route.isNullOrBlank()) {
            routeChannel?.invokeMethod("onRoute", route)
        }
    }

    private fun extractWidgetRoute(intent: Intent?): String? {
        return intent?.getStringExtra(EXTRA_WIDGET_ROUTE)?.trim()?.takeIf { it.isNotEmpty() }
    }
}
