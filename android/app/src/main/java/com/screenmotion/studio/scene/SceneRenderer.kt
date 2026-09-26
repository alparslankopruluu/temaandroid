package com.screenmotion.studio.scene

import android.animation.ValueAnimator
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.compose.animation.core.withInfiniteAnimationFrameNanos
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import com.screenmotion.studio.export.SceneBitmapRenderer
import com.screenmotion.studio.model.SceneConfiguration
import com.screenmotion.studio.model.Theme
import kotlin.math.exp

data class SceneSnapshot(
    val position: SceneVector = SceneVector.ZERO,
    val rotation: Double = 0.0,
    val score: Int = 0,
    val highScore: Int = 0,
    val tapResponse: Double = 0.0,
    val obstacles: List<SceneObstacle> = emptyList(),
)

@Composable
fun SceneRenderer(
    theme: Theme,
    configuration: SceneConfiguration,
    modifier: Modifier = Modifier,
    isActive: Boolean = true,
    reducedMotion: Boolean = false,
    showHud: Boolean = true,
    onHighScore: (Int) -> Unit = {},
) {
    val context = LocalContext.current
    val systemReducedMotion = remember(context) { !ValueAnimator.areAnimatorsEnabled() }
    val shouldReduceMotion = reducedMotion || systemReducedMotion
    val scorePreferences = remember(context) {
        context.getSharedPreferences("screenmotion-pixel-scores", Context.MODE_PRIVATE)
    }
    val tilt = rememberTilt(context, isActive && !shouldReduceMotion)
    var drag by remember(theme.id) { mutableStateOf<SceneVector?>(null) }
    var tap by remember(theme.id) { mutableStateOf<SceneVector?>(null) }
    var elapsed by remember(theme.id) { mutableDoubleStateOf(0.0) }
    var snapshot by remember(theme.id) { mutableStateOf(SceneSnapshot()) }
    var touching by remember(theme.id) { mutableStateOf(false) }
    var touchX by remember(theme.id) { mutableStateOf<Float?>(null) }
    var touchY by remember(theme.id) { mutableStateOf<Float?>(null) }
    var tapTime by remember(theme.id) { mutableDoubleStateOf(Double.NEGATIVE_INFINITY) }
    var smoothed by remember(theme.id) { mutableStateOf(SceneVector.ZERO) }
    val behavior = remember(theme.id) {
        if (theme.remoteScene != null) return@remember null
        theme.interaction?.let {
            InteractiveSceneBehavior(
                it,
                configuration.scoreMode,
                InteractiveSceneBehavior.seed(theme.id),
                scorePreferences.getInt(theme.id, 0),
            )
        }
    }

    LaunchedEffect(configuration.scoreMode) { behavior?.setScoreMode(configuration.scoreMode) }
    LaunchedEffect(theme.id, isActive, shouldReduceMotion) {
        if (!isActive || shouldReduceMotion) return@LaunchedEffect
        var previous = 0L
        while (true) {
            withInfiniteAnimationFrameNanos { now ->
                val delta = if (previous == 0L) 0.0 else (now - previous) / 1_000_000_000.0
                previous = now
                elapsed += delta.coerceAtMost(.05)
                if (theme.remoteScene != null) {
                    val target = if (touching) drag ?: SceneVector.ZERO else SceneVector(tilt.value.x * 0.9, tilt.value.y * 0.55)
                    val blend = 1 - exp(-delta.coerceAtMost(.05) * 8)
                    smoothed = SceneVector(
                        smoothed.x + (target.x - smoothed.x) * blend,
                        smoothed.y + (target.y - smoothed.y) * blend,
                    )
                }
                val input = SceneInput(tilt = tilt.value, drag = drag, tap = tap)
                tap = null
                behavior?.update(delta, elapsed, input)?.forEach {
                    if (it is SceneEvent.HighScoreChanged) {
                        scorePreferences.edit().putInt(theme.id, it.score).apply()
                        onHighScore(it.score)
                    }
                }
                snapshot = behavior?.let {
                    SceneSnapshot(
                        position = it.state.position,
                        rotation = it.state.rotation,
                        score = it.state.score,
                        highScore = it.state.highScore,
                        obstacles = it.obstacles.map(SceneObstacle::copy),
                    )
                } ?: SceneSnapshot(position = drag ?: tilt.value)
            }
        }
    }

    val displacement = drag ?: if (reducedMotion) SceneVector.ZERO else tilt.value
    Box(
        modifier = modifier
            .pointerInput(theme.id) {
                detectDragGestures(
                    onDragStart = { position ->
                        touching = true
                        touchX = position.x
                        touchY = position.y
                        drag = normalized(position.x, position.y, size.width.toFloat(), size.height.toFloat())
                    },
                    onDragEnd = {
                        drag = null
                        touching = false
                        if (theme.remoteScene != null) tapTime = elapsed
                    },
                    onDragCancel = { drag = null; touching = false },
                ) { change, _ ->
                    touching = true
                    touchX = change.position.x
                    touchY = change.position.y
                    drag = normalized(change.position.x, change.position.y, size.width.toFloat(), size.height.toFloat())
                }
            }
            .pointerInput(theme.id) {
                detectTapGestures { position ->
                    touchX = position.x
                    touchY = position.y
                    if (theme.remoteScene != null) tapTime = elapsed
                    tap = normalized(position.x, position.y, size.width.toFloat(), size.height.toFloat())
                }
            },
    ) {
        Canvas(Modifier.fillMaxSize()) {
            drawIntoCanvas { canvas ->
                SceneBitmapRenderer.draw(
                    context,
                    canvas.nativeCanvas,
                    theme,
                    configuration,
                    if (shouldReduceMotion) 0.0 else elapsed,
                    displacement.x.toFloat(),
                    displacement.y.toFloat(),
                    snapshot,
                    if (theme.remoteScene == null || shouldReduceMotion) null else RemoteMotion(
                        displacementX = smoothed.x,
                        displacementY = smoothed.y,
                        touchX = touchX,
                        touchY = touchY,
                        tapTime = tapTime,
                    ),
                )
            }
        }
        if (showHud && theme.isPixel && configuration.scoreMode && theme.supportsScore) {
            androidx.compose.material3.Text(
                text = snapshot.score.toString() + "  ★ " + snapshot.highScore,
                color = Color(0xFFC2FA6B),
                modifier = Modifier.graphicsLayer { translationX = 18f; translationY = 18f },
            )
        }
    }
}

private fun normalized(x: Float, y: Float, width: Float, height: Float) =
    SceneVector(
        x = ((x / width.coerceAtLeast(1f)) * 2 - 1).toDouble(),
        y = (1 - (y / height.coerceAtLeast(1f)) * 2).toDouble(),
    ).bounded()

private data class TiltState(val value: SceneVector)

@Composable
private fun rememberTilt(context: Context, enabled: Boolean): TiltState {
    var value by remember { mutableStateOf(SceneVector.ZERO) }
    DisposableEffect(context, enabled) {
        if (!enabled) return@DisposableEffect onDispose {}
        val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                value = SceneVector(
                    (event.values[0] / 7.5f).toDouble(),
                    (-event.values[1] / 7.5f).toDouble(),
                ).bounded()
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        sensor?.let { manager.registerListener(listener, it, SensorManager.SENSOR_DELAY_GAME) }
        onDispose { manager.unregisterListener(listener) }
    }
    return TiltState(value)
}
