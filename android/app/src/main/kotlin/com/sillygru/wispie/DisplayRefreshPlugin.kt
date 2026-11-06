package com.sillygru.wispie

import android.os.Build
import android.view.Display
import android.view.Window
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** Best-effort refresh hints, avoiding potentially disruptive sub-60 mode switches. */
class DisplayRefreshPlugin : MethodCallHandler {
    private val channelName = "wispie/display_refresh"
    private var window: Window? = null

    fun initialize(flutterEngine: FlutterEngine, activity: MainActivity) {
        this.window = activity.window
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setPreferredRefreshRate" -> {
                val hz = (call.argument<Double>("hz") ?: (call.argument<Int>("hz")?.toDouble())) ?: 60.0
                setPreferred(hz)
                result.success(null)
            }
            "clearPreferredRefreshRate" -> {
                clearPreferred()
                result.success(null)
            }
            "getSupportedModes" -> result.success(getSupportedModesPayload())
            "getPanelInfo" -> result.success(getPanelInfoPayload())
            else -> result.notImplemented()
        }
    }

    private fun getSupportedModesPayload(): List<Map<String, Any>> {
        val w = window ?: return emptyList()
        return try {
            val display = displayOf(w) ?: return emptyList()
            display.supportedModes.map { m ->
                mapOf(
                    "modeId" to m.modeId,
                    "width" to m.physicalWidth,
                    "height" to m.physicalHeight,
                    "refreshRate" to m.refreshRate.toDouble(),
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    /** Public display modes do not identify the panel technology. */
    private fun getPanelInfoPayload(): Map<String, Any> {
        val w = window ?: return emptyPanelInfo()
        return try {
            val display = displayOf(w) ?: return emptyPanelInfo()
            val rates = LinkedHashSet<Float>()
            display.supportedModes.forEach { rates.add(it.refreshRate) }
            mapOf(
                "kind" to "unknown",
                "minRate" to (rates.minOrNull()?.toDouble() ?: 0.0),
                "maxRate" to (rates.maxOrNull()?.toDouble() ?: 0.0),
            )
        } catch (_: Exception) {
            emptyPanelInfo()
        }
    }

    private fun emptyPanelInfo(): Map<String, Any> = mapOf(
        "kind" to "unknown",
        "minRate" to 0.0,
        "maxRate" to 0.0,
    )

    private fun setPreferred(hz: Double) {
        val w = window ?: return
        try {
            val display = displayOf(w) ?: return
            val target = if (hz < 60.0) 60.0 else hz
            val current = display.mode
            val sameSize = display.supportedModes.filter {
                it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight
            }
            val best = when {
                target <= 60.5 ->
                    sameSize.filter { it.refreshRate >= 59.5f }.minByOrNull { it.refreshRate }
                target >= 119.5 ->
                    sameSize.filter { it.refreshRate <= 120.5f }.maxByOrNull { it.refreshRate }
                else -> sameSize.minByOrNull { kotlin.math.abs(it.refreshRate - target.toFloat()) }
            } ?: sameSize.maxByOrNull { it.refreshRate }
            if (best == null) return

            val params = w.attributes
            params.preferredDisplayModeId = 0
            params.preferredRefreshRate = best.refreshRate
            w.attributes = params
        } catch (_: Exception) {
            // Best effort.
        }
    }

    private fun clearPreferred() {
        val w = window ?: return
        try {
            val params = w.attributes
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                params.preferredDisplayModeId = 0
            }
            params.preferredRefreshRate = 0f
            w.attributes = params
        } catch (_: Exception) {
            // Best effort.
        }
    }

    private fun displayOf(w: Window): Display? = try {
        w.decorView.display
    } catch (_: Exception) {
        null
    }

    fun cleanup() {
        clearPreferred()
    }
}
