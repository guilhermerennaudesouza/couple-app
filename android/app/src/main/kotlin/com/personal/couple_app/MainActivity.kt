package com.personal.couple_app

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val WIDGET_ROUTE_CHANNEL = "com.personal.couple_app/widget_route"
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
