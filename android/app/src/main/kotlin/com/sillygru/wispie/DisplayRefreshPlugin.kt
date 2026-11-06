package com.sillygru.wispie

import android.os.Build
import android.view.Display
import android.view.Window
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Lets the player hint the display refresh rate, and keeps panels whose rates
 * are separate modes out of anything below 60 Hz.
 *
 * Two panel classes, told apart by what the display advertises:
 *
 * * Discrete (LTPS) — every rate is a `Display.Mode`, so a hint selects the
 *   closest mode at or below the request and a rate the panel does not have is
 *   never invented. Nothing below 60 is ever selected: on these panels that is a
 *   real mode switch, which flickers for no visible win.
 * * Variable (LTPO) — the panel advertises a seamless ladder of rates on the
 *   current mode, so the hint becomes a min/max window on that mode and the
 *   driver interpolates. Below 60 the window is released and the system runs its
 *   own 1-120.
 *
 * Failures are silent — the hint is best effort.
 */
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

    /** Panel class plus its rates, for the Dart side's policy and diagnostics. */
    private fun getPanelInfoPayload(): Map<String, Any> {
        val w = window ?: return emptyPanelInfo()
        return try {
            val display = displayOf(w) ?: return emptyPanelInfo()
            val rates = LinkedHashSet<Float>()
            display.supportedModes.forEach { rates.add(it.refreshRate) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display.mode.supportedRefreshRates.forEach { rates.add(it) }
            }
            mapOf(
                "kind" to if (isVariable(display)) "variable" else "discrete",
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

    /**
     * A variable panel advertises rates it can hit without a mode switch, and at
     * least one of them is below 60. A panel where a sub-60 rate is its own mode
     * is discrete — those keep the 60 floor.
     */
    private fun isVariable(display: Display): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return try {
            val ladder = display.mode.supportedRefreshRates
            val low = ladder.minOrNull() ?: return false
            val high = ladder.maxOrNull() ?: return false
            val subSixtyMode = display.supportedModes.any { it.refreshRate < 59.5f }
            low < 59.5f && high >= 89.5f && !subSixtyMode
        } catch (_: Exception) {
            false
        }
    }

    private fun setPreferred(hz: Double) {
        val w = window ?: return
        try {
            val display = displayOf(w) ?: return
            if (isVariable(display)) {
                hintVariable(w, hz)
                return
            }

            // Discrete panels: 60 is the floor. A 30Hz request on a 30/60 panel is
            // a mode switch, not a frame-rate saving.
            val target = if (hz < 60.0) 60.0 else hz
            val current = display.mode
            val sameSize = display.supportedModes.filter {
                it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight
            }
            if (sameSize.size <= 1) {
                hintSingleMode(w, target)
                return
            }
            // Closest *available* rate, never an invented one: 60/90 lands on 90
            // for a 120 request, 60/90/120 lands on 120.
            val best = when {
                target <= 60.5 ->
                    sameSize.filter { it.refreshRate >= 59.5f }.minByOrNull { it.refreshRate }
                target >= 119.5 ->
                    sameSize.filter { it.refreshRate <= 120.5f }.maxByOrNull { it.refreshRate }
                else -> sameSize.minByOrNull { kotlin.math.abs(it.refreshRate - target.toFloat()) }
            } ?: sameSize.maxByOrNull { it.refreshRate }
            if (best == null) {
                hintSingleMode(w, target)
                return
            }

            val params = w.attributes
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                params.preferredDisplayModeId = best.modeId
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                params.preferredRefreshRate = target.toFloat()
            }
            w.attributes = params
        } catch (_: Exception) {
            // Best effort.
        }
    }

    private fun hintVariable(w: Window, hz: Double) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val params = w.attributes
            // Never a mode id here: a mode switch is exactly what a variable
            // panel must not do.
            params.preferredDisplayModeId = 0
            if (hz >= 60.0) {
                params.preferredMinDisplayRefreshRate = hz.toFloat()
                params.preferredMaxDisplayRefreshRate = hz.toFloat()
            } else {
                params.preferredMinDisplayRefreshRate = 0f
                params.preferredMaxDisplayRefreshRate = 0f
            }
            w.attributes = params
        } catch (_: Exception) {
            // Best effort.
        }
    }

    /** Single-mode panel: there is nothing to switch to, so only the rate hint. */
    private fun hintSingleMode(w: Window, hz: Double) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        try {
            val params = w.attributes
            params.preferredRefreshRate = hz.toFloat()
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
                params.preferredMinDisplayRefreshRate = 0f
                params.preferredMaxDisplayRefreshRate = 0f
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                params.preferredRefreshRate = 0f
            }
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
