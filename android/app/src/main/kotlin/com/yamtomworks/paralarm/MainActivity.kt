package com.yamtomworks.paralarm

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "codex_paralarm/alarm_sound"
    private var toneGenerator: ToneGenerator? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getVolume") {
                    result.success(getAlarmVolume())
                    return@setMethodCallHandler
                }

                if (call.method == "vibrate") {
                    val pattern = call.argument<String>("pattern") ?: "pulse"
                    playVibration(pattern)
                    result.success(null)
                    return@setMethodCallHandler
                }

                if (call.method != "play") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val sound = call.argument<String>("sound") ?: "alert"
                playAlarmSound(sound)
                result.success(null)
            }
    }

    private fun playAlarmSound(sound: String) {
        if (sound == "loudBeep") {
            repeat(18) { index ->
                handler.postDelayed({
                    alarmToneGenerator().startTone(ToneGenerator.TONE_PROP_BEEP2, 52)
                }, index * 80L)
            }
            return
        }

        val tone = when (sound) {
            "click" -> ToneGenerator.TONE_PROP_BEEP
            "danger" -> ToneGenerator.TONE_PROP_BEEP2
            else -> ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD
        }
        val durationMs = when (sound) {
            "click" -> 160
            "danger" -> 75
            else -> 650
        }
        alarmToneGenerator().startTone(tone, durationMs)
    }

    private fun alarmToneGenerator(): ToneGenerator {
        return toneGenerator ?: ToneGenerator(AudioManager.STREAM_ALARM, 100).also {
            toneGenerator = it
        }
    }

    private fun getAlarmVolume(): Double {
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        if (maxVolume <= 0) {
            return 0.0
        }

        return audioManager.getStreamVolume(AudioManager.STREAM_ALARM).toDouble() / maxVolume
    }

    private fun playVibration(patternName: String) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }

        val pattern = when (patternName) {
            "urgent" -> longArrayOf(0, 500, 180, 500, 180, 700)
            "long" -> longArrayOf(0, 1400)
            else -> longArrayOf(0, 140, 120, 140, 120, 140)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val amplitudes = when (patternName) {
                "urgent" -> intArrayOf(0, 255, 0, 255, 0, 255)
                "long" -> intArrayOf(0, 230)
                else -> intArrayOf(0, 210, 0, 210, 0, 210)
            }
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, amplitudes, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
