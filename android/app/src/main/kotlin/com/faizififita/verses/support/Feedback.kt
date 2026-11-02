package com.faizififita.verses.support

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

object Feedback {
    private var vibrator: Vibrator? = null
    private val handler = Handler(Looper.getMainLooper())
    private val ripple = Any()

    fun install(context: Context) {
        vibrator = if (Build.VERSION.SDK_INT >= 31) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    fun tap() = primitive(PRIMITIVE_TICK, 0.5f, VibrationEffect.EFFECT_TICK)

    fun hide() = primitive(PRIMITIVE_CLICK, 0.8f, VibrationEffect.EFFECT_CLICK)

    fun hideTick() = primitive(PRIMITIVE_LOW_TICK, 0.7f, VibrationEffect.EFFECT_TICK)

    fun flip() = primitive(PRIMITIVE_CLICK, 1f, VibrationEffect.EFFECT_HEAVY_CLICK)

    fun reveal() = primitive(PRIMITIVE_TICK, 0.7f, VibrationEffect.EFFECT_TICK)

    fun scrub() = primitive(PRIMITIVE_TICK, 0.6f, VibrationEffect.EFFECT_TICK)

    fun recitationMiss() {
        val vibrator = vibrator ?: return
        if (Build.VERSION.SDK_INT >= 30 && vibrator.areAllPrimitivesSupported(PRIMITIVE_CLICK)) {
            vibrator.vibrate(
                VibrationEffect.startComposition()
                    .addPrimitive(PRIMITIVE_CLICK, 1f)
                    .addPrimitive(PRIMITIVE_CLICK, 1f, 90)
                    .addPrimitive(PRIMITIVE_CLICK, 0.8f, 90)
                    .compose()
            )
        } else if (Build.VERSION.SDK_INT >= 29) {
            vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_DOUBLE_CLICK))
        }
    }

    fun sessionComplete() {
        val vibrator = vibrator ?: return
        if (Build.VERSION.SDK_INT >= 30 && vibrator.areAllPrimitivesSupported(PRIMITIVE_CLICK, PRIMITIVE_TICK)) {
            vibrator.vibrate(
                VibrationEffect.startComposition()
                    .addPrimitive(PRIMITIVE_TICK, 0.6f)
                    .addPrimitive(PRIMITIVE_CLICK, 1f, 110)
                    .compose()
            )
        } else if (Build.VERSION.SDK_INT >= 29) {
            vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_DOUBLE_CLICK))
        }
    }

    fun cascadeRipple(delays: List<Double>) {
        handler.removeCallbacksAndMessages(ripple)
        val sorted = delays.sorted()
        val span = sorted.lastOrNull()?.takeIf { it > 0 } ?: return
        var lastScheduled = Double.NEGATIVE_INFINITY
        for (delay in sorted) {
            if (delay - lastScheduled < 0.05) continue
            lastScheduled = delay
            val intensity = (0.35 + 0.3 * (delay / span)).toFloat()
            handler.postAtTime(
                { primitive(PRIMITIVE_LOW_TICK, intensity, VibrationEffect.EFFECT_TICK) },
                ripple,
                android.os.SystemClock.uptimeMillis() + (delay * 1000).toLong(),
            )
        }
    }

    private fun primitive(id: Int, scale: Float, fallback: Int) {
        val vibrator = vibrator ?: return
        if (Build.VERSION.SDK_INT >= 30 && vibrator.areAllPrimitivesSupported(id)) {
            vibrator.vibrate(VibrationEffect.startComposition().addPrimitive(id, scale).compose())
        } else if (Build.VERSION.SDK_INT >= 29) {
            vibrator.vibrate(VibrationEffect.createPredefined(fallback))
        } else {
            vibrator.vibrate(VibrationEffect.createOneShot(12, (255 * scale).toInt().coerceIn(1, 255)))
        }
    }

    private const val PRIMITIVE_CLICK = 1
    private const val PRIMITIVE_TICK = 7
    private const val PRIMITIVE_LOW_TICK = 8
}
