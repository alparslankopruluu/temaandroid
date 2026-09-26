package com.screenmotion.studio.wallpaper

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.service.wallpaper.WallpaperService
import android.view.MotionEvent
import android.view.SurfaceHolder
import com.screenmotion.studio.export.SceneBitmapRenderer
import com.screenmotion.studio.model.SceneConfiguration
import com.screenmotion.studio.model.Theme
import com.screenmotion.studio.scene.InteractiveSceneBehavior
import com.screenmotion.studio.scene.RemoteMotion
import com.screenmotion.studio.scene.SceneInput
import com.screenmotion.studio.scene.SceneSnapshot
import com.screenmotion.studio.scene.SceneVector
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

object WallpaperSelection {
    private const val FILE = "screenmotion-wallpaper"
    private const val THEME = "theme"
    private const val CONFIGURATION = "configuration"
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    fun save(context: Context, theme: Theme, configuration: SceneConfiguration) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putString(THEME, json.encodeToString(theme))
            .putString(CONFIGURATION, json.encodeToString(configuration))
            .apply()
    }

    fun load(context: Context): Pair<Theme, SceneConfiguration>? {
        val preferences = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val theme = preferences.getString(THEME, null) ?: return null
        val config = preferences.getString(CONFIGURATION, null) ?: return null
        return runCatching {
            json.decodeFromString<Theme>(theme) to json.decodeFromString<SceneConfiguration>(config)
        }.getOrNull()
    }
}

class ScreenMotionWallpaperService : WallpaperService() {
    override fun onCreateEngine(): Engine = ScreenMotionEngine()

    private inner class ScreenMotionEngine : Engine(), SensorEventListener {
        private val handler = Handler(Looper.getMainLooper())
        private var visible = false
        private var touchPhase = 0.0
        private var touch: SceneVector? = null
        private var tap: SceneVector? = null
        private var activeKey: String? = null
        private var behavior: InteractiveSceneBehavior? = null
        private var elapsed = 0.0
        private var previousFrameNanos = 0L
        private val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        private val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        private var motionX = 0f
        private var motionY = 0f
        private var touchX: Float? = null
        private var touchY: Float? = null
        private var tapAt = Double.NEGATIVE_INFINITY
        private val render = object : Runnable {
            override fun run() {
                drawFrame()
                if (visible && ValueAnimator.areAnimatorsEnabled()) handler.postDelayed(this, frameDelay())
            }
        }

        init { setTouchEventsEnabled(true) }

        override fun onVisibilityChanged(visible: Boolean) {
            this.visible = visible
            handler.removeCallbacks(render)
            if (visible) {
                if (ValueAnimator.areAnimatorsEnabled()) {
                    accelerometer?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
                }
                render.run()
            } else {
                sensorManager.unregisterListener(this)
            }
        }

        override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            super.onSurfaceChanged(holder, format, width, height)
            if (visible) {
                handler.removeCallbacks(render)
                render.run()
            }
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            visible = false
            sensorManager.unregisterListener(this)
            handler.removeCallbacks(render)
            super.onSurfaceDestroyed(holder)
        }

        override fun onTouchEvent(event: MotionEvent) {
            if (event.action == MotionEvent.ACTION_DOWN || event.action == MotionEvent.ACTION_MOVE) {
                touchX = event.x
                touchY = event.y
                touchPhase = (event.x / surfaceHolder.surfaceFrame.width().coerceAtLeast(1)) * Math.PI * 2
                val bounds = surfaceHolder.surfaceFrame
                val point = SceneVector(
                    (event.x / bounds.width().coerceAtLeast(1) * 2 - 1).toDouble(),
                    (1 - event.y / bounds.height().coerceAtLeast(1) * 2).toDouble(),
                ).bounded()
                touch = point
                if (event.action == MotionEvent.ACTION_DOWN) tap = point
                if (visible) {
                    handler.removeCallbacks(render)
                    render.run()
                }
            }
            if (event.action == MotionEvent.ACTION_UP) tapAt = elapsed
            if (event.action == MotionEvent.ACTION_UP || event.action == MotionEvent.ACTION_CANCEL) touch = null
            if (event.action == MotionEvent.ACTION_CANCEL) {
                touchX = null
                touchY = null
            }
            super.onTouchEvent(event)
        }

        override fun onSensorChanged(event: SensorEvent) {
            if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
            motionX = motionX * .8f + (event.values[0] / 9.81f).coerceIn(-1f, 1f) * .2f
            motionY = motionY * .8f + (-event.values[1] / 9.81f).coerceIn(-1f, 1f) * .2f
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

        override fun onDestroy() {
            handler.removeCallbacks(render)
            super.onDestroy()
        }

        private fun drawFrame() {
            val selection = WallpaperSelection.load(this@ScreenMotionWallpaperService) ?: return
            val key = selection.first.id + selection.second.toString()
            if (activeKey != key) {
                activeKey = key
                behavior = selection.first.interaction?.let {
                    InteractiveSceneBehavior(it, selection.second.scoreMode, InteractiveSceneBehavior.seed(selection.first.id))
                }
                elapsed = 0.0
                previousFrameNanos = 0L
            }
            val now = System.nanoTime()
            val delta = if (previousFrameNanos == 0L) 0.0 else ((now - previousFrameNanos) / 1_000_000_000.0).coerceIn(0.0, .05)
            previousFrameNanos = now
            elapsed += delta
            val input = SceneInput(
                tilt = SceneVector(motionX.toDouble(), motionY.toDouble()).bounded(),
                drag = touch,
                tap = tap,
            )
            tap = null
            behavior?.update(delta, elapsed, input)
            var canvas: Canvas? = null
            try {
                canvas = surfaceHolder.lockCanvas()
                if (canvas != null) {
                    SceneBitmapRenderer.draw(
                        this@ScreenMotionWallpaperService,
                        canvas,
                        selection.first,
                        selection.second,
                        elapsed + touchPhase,
                        motionX,
                        motionY,
                        behavior?.snapshot() ?: SceneSnapshot(),
                        if (selection.first.remoteScene == null) null else RemoteMotion(
                            displacementX = motionX * 0.9,
                            displacementY = motionY * 0.55,
                            touchX = touchX,
                            touchY = touchY,
                            tapTime = tapAt,
                        ),
                    )
                }
            } finally {
                if (canvas != null) surfaceHolder.unlockCanvasAndPost(canvas)
            }
        }

        private fun frameDelay(): Long {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            return if (power.isPowerSaveMode) 33L else 16L
        }
    }
}
