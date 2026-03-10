package com.example.medsoft_doctor

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // TextureView instead of SurfaceView: Samsung One UI has a known bug where
    // SurfaceView surfaces are not redrawn after the PiP window is created,
    // causing the entire PiP window to show white. TextureView uses Android's
    // hardware-accelerated layer compositing which handles PiP correctly on One UI.
    override fun getRenderMode(): RenderMode = RenderMode.texture
    private val PIP_CHANNEL = "pip_channel"
    private val SCREEN_CAPTURE_CHANNEL = "screen_capture_channel"
    private var isInCall = false
    private var pipChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CAPTURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForeground" -> {
                        val intent = Intent(this, ScreenCaptureService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopForeground" -> {
                        stopService(Intent(this, ScreenCaptureService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipChannel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPiP" -> {
                        isInCall = true
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(9, 16))
                                .setAutoEnterEnabled(true)
                                .build()
                            setPictureInPictureParams(params)
                            // On Android 12+, setAutoEnterEnabled handles entry automatically.
                            // Only call enterPictureInPictureMode manually if not already in PiP
                            // to avoid double-triggering which confuses the system's "expand" intent
                            // (causing zoom-only behavior on Samsung/MIUI on repeated PiP cycles).
                            if (!isInPictureInPictureMode) {
                                enterPictureInPictureMode(params)
                            }
                            result.success(true)
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(9, 16))
                                .build()
                            enterPictureInPictureMode(params)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "setupPiP" -> {
                        isInCall = true
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(9, 16))
                                .setAutoEnterEnabled(true)
                                .build()
                            setPictureInPictureParams(params)
                        }
                        result.success(true)
                    }
                    "dispose" -> {
                        isInCall = false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val params = PictureInPictureParams.Builder()
                                .setAutoEnterEnabled(false)
                                .build()
                            setPictureInPictureParams(params)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onPictureInPictureModeChanged(isInPip: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPip, newConfig)
        notifyPipState(isInPip)
    }

    // Samsung One UI (Note 10, S-series) may not reliably fire
    // onPictureInPictureModeChanged. onMultiWindowModeChanged fires for ALL
    // multi-window changes and isInPictureInPictureMode gives the exact state.
    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notifyPipState(isInPictureInPictureMode)
        }
    }

    private fun notifyPipState(isInPip: Boolean) {
        pipChannel?.invokeMethod("pipModeChanged", isInPip)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isInCall && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            // Android 12+ uses setAutoEnterEnabled — no manual call needed
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(9, 16))
                .build()
            enterPictureInPictureMode(params)
        }
    }
}
