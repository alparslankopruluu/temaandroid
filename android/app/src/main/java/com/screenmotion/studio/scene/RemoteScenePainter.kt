package com.screenmotion.studio.scene

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.util.LruCache
import com.screenmotion.studio.data.RemoteAssetCache
import com.screenmotion.studio.model.RemoteLayerAnimation
import com.screenmotion.studio.model.RemoteParticlePreset
import com.screenmotion.studio.model.RemoteSceneRecipe
import com.screenmotion.studio.model.RemoteTouchResponse
import com.screenmotion.studio.model.SceneConfiguration
import com.screenmotion.studio.model.Theme
import java.io.File
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

data class RemoteMotion(
    val displacementX: Double = 0.0,
    val displacementY: Double = 0.0,
    val touchX: Float? = null,
    val touchY: Float? = null,
    val tapTime: Double = Double.NEGATIVE_INFINITY,
)

object RemoteScenePainter {
    private val bitmaps = object : LruCache<String, Bitmap>(48 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap): Int = value.allocationByteCount
    }

    fun draw(
        context: Context,
        canvas: Canvas,
        theme: Theme,
        configuration: SceneConfiguration,
        time: Double,
        motion: RemoteMotion,
    ) {
        val recipe = theme.remoteScene ?: return
        val width = canvas.width.toFloat().coerceAtLeast(1f)
        val height = canvas.height.toFloat().coerceAtLeast(1f)
        canvas.drawColor(Color.rgb(6, 9, 20))
        val intensity = configuration.intensity.coerceIn(0f, 1f).toDouble()
        val depth = configuration.depth.coerceIn(0f, 1f).toDouble()
        val particleAmount = configuration.particles.coerceIn(0f, 1f).toDouble()
        recipe.layers.forEach { layer ->
            val image = bitmap(context, theme, layer.asset) ?: return@forEach
            val phase = time * (Math.PI * 2 / max(layer.period, 0.5))
            val parallax = layer.parallax * depth * intensity
            var x = width / 2 + motion.displacementX * width * 0.045 * parallax
            var y = height / 2 + motion.displacementY * height * 0.045 * parallax
            var rotation = 0.0
            var alpha = 1.0
            var scale = 1.0
            when (layer.animation) {
                RemoteLayerAnimation.still -> Unit
                RemoteLayerAnimation.sway -> rotation = sin(phase) * layer.amount * 0.07 * intensity
                RemoteLayerAnimation.drift -> {
                    x += sin(phase) * layer.amount * 0.018 * width
                    y += cos(phase * 0.7) * layer.amount * 0.01 * height
                }
                RemoteLayerAnimation.flicker -> alpha = 1 - layer.amount * 0.18 * (0.5 + 0.5 * sin(phase * 1.8))
                RemoteLayerAnimation.pulse -> scale = 1 + layer.amount * 0.012 * sin(phase) * intensity
            }
            val layerWidth = width * (1.05 + abs(layer.parallax) * 0.025) * scale
            val layerHeight = height * (1.05 + abs(layer.parallax) * 0.025) * scale
            val matrix = Matrix().apply {
                postScale((layerWidth / image.width).toFloat(), (layerHeight / image.height).toFloat())
                postRotate(Math.toDegrees(-rotation).toFloat(), (layerWidth / 2).toFloat(), (layerHeight / 2).toFloat())
                postTranslate((x - layerWidth / 2).toFloat(), height - (y + layerHeight / 2).toFloat())
            }
            canvas.drawBitmap(image, matrix, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                isFilterBitmap = !theme.isPixel
                this.alpha = (alpha.coerceIn(0.0, 1.0) * 255).toInt()
            })
        }
        if (particleAmount >= 0.01) {
            drawParticles(canvas, recipe, width, height, time, intensity, particleAmount, motion, theme.isPixel)
        }
        drawRipple(canvas, recipe, width, time, motion)
        drawLight(canvas, recipe, width, height, time)
    }

    private fun drawParticles(
        canvas: Canvas,
        recipe: RemoteSceneRecipe,
        width: Float,
        height: Float,
        time: Double,
        intensity: Double,
        particleAmount: Double,
        motion: RemoteMotion,
        pixel: Boolean,
    ) {
        val touch = motion.touchX?.let { x -> motion.touchY?.let { y -> x to (height - y) } }
        val tapAge = time - motion.tapTime
        recipe.particles.orEmpty().forEachIndexed { emitterIndex, emitter ->
            repeat(emitter.count.coerceIn(0, 120)) { index ->
                val seed = (index + 1 + emitterIndex * 37).toDouble()
                val baseX = (seed * 0.61803398875) % 1.0
                val baseY = (seed * 0.38196601125 + 0.17) % 1.0
                val speed = (0.012 + emitter.speed * 0.045) * (0.35 + intensity)
                val travelsUp = emitter.preset in setOf(
                    RemoteParticlePreset.ember,
                    RemoteParticlePreset.smoke,
                    RemoteParticlePreset.firefly,
                    RemoteParticlePreset.bubble,
                )
                var x = baseX * width + motion.displacementX * width * 0.025 * intensity
                var y = wrapped(baseY + (if (travelsUp) 1.0 else -1.0) * time * speed * (0.5 + baseX)) * height
                if (touch != null && tapAge >= 0 && tapAge < 1.1) {
                    when (recipe.interaction) {
                        RemoteTouchResponse.push -> {
                            val dx = x - touch.first
                            val dy = y - touch.second
                            val distance = max(hypot(dx, dy), 1.0)
                            val force = (1.1 - tapAge) * 24 * emitter.speed.coerceIn(0.0, 1.0)
                            x += dx / distance * force
                            y += dy / distance * force
                        }
                        RemoteTouchResponse.swirl -> {
                            val dx = x - touch.first
                            val dy = y - touch.second
                            val angle = (1.1 - tapAge) * 1.4
                            x = touch.first + dx * cos(angle) - dy * sin(angle)
                            y = touch.second + dx * sin(angle) + dy * cos(angle)
                        }
                        RemoteTouchResponse.emberBurst, RemoteTouchResponse.bubbleTrail -> {
                            if (emitter.preset == RemoteParticlePreset.ember || emitter.preset == RemoteParticlePreset.bubble) {
                                val angle = seed * 2.399963
                                val distance = (18 + (index % 28) * 2) * (tapAge + 0.2)
                                x = touch.first + cos(angle) * distance
                                y = touch.second + sin(angle) * distance + tapAge * 20
                            }
                        }
                        RemoteTouchResponse.none, RemoteTouchResponse.ripple -> Unit
                    }
                }
                val flicker = 0.55 + 0.45 * abs(sin(time * (0.8 + seed * 0.025) + seed))
                var alpha = particleAmount * when (emitter.preset) {
                    RemoteParticlePreset.rain -> 0.65
                    RemoteParticlePreset.smoke -> 0.32 + 0.15 * flicker
                    RemoteParticlePreset.snow, RemoteParticlePreset.bubble -> 0.68
                    RemoteParticlePreset.ember, RemoteParticlePreset.firefly, RemoteParticlePreset.stardust -> flicker
                }
                if (emitter.preset in setOf(RemoteParticlePreset.ember, RemoteParticlePreset.firefly, RemoteParticlePreset.stardust)) {
                    alpha *= 0.58 + 0.42 * abs(sin(time * 2 + seed))
                }
                val paint = particlePaint(emitter.preset, alpha, pixel)
                val scale = max(0.75, width / 390.0).toFloat()
                canvas.save()
                canvas.translate(x.toFloat(), height - y.toFloat())
                canvas.scale(scale, scale)
                when (emitter.preset) {
                    RemoteParticlePreset.rain -> {
                        canvas.rotate(Math.toDegrees(-0.12).toFloat())
                        canvas.drawRect(
                            RectF(-0.6f, -(10 + index % 8) / 2f, 0.6f, (10 + index % 8) / 2f),
                            paint,
                        )
                    }
                    RemoteParticlePreset.smoke -> canvas.drawCircle(0f, 0f, (3 + index % 6).toFloat(), paint)
                    RemoteParticlePreset.bubble -> {
                        paint.style = Paint.Style.STROKE
                        paint.strokeWidth = 1f
                        canvas.drawCircle(0f, 0f, (2 + index % 4).toFloat(), paint)
                    }
                    else -> canvas.drawCircle(0f, 0f, (1 + index % 3).toFloat(), paint)
                }
                canvas.restore()
            }
        }
    }

    private fun drawRipple(canvas: Canvas, recipe: RemoteSceneRecipe, width: Float, time: Double, motion: RemoteMotion) {
        if (recipe.interaction != RemoteTouchResponse.ripple) return
        val x = motion.touchX ?: return
        val y = motion.touchY ?: return
        val age = time - motion.tapTime
        if (age < 0 || age >= 1.1) return
        val progress = (age / 1.1).toFloat()
        canvas.drawCircle(x, y, 1f + progress * width * 0.12f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = max(1f, width / 260f)
            color = Color.WHITE
            alpha = ((1f - progress) * 0.85f * 255).toInt()
        })
    }

    private fun drawLight(canvas: Canvas, recipe: RemoteSceneRecipe, width: Float, height: Float, time: Double) {
        val light = recipe.light ?: return
        val phase = time * (Math.PI * 2 / max(light.period, 0.5))
        val alpha = 0.48 + 0.52 * (1 - light.flicker * (0.5 + 0.5 * sin(phase)))
        val radius = max(1.0, width * light.radius / 2.0).toFloat()
        val color = parseColor(light.color)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
                (width * light.x).toFloat(),
                (height * (1 - light.y)).toFloat(),
                radius,
                intArrayOf(color, color, Color.TRANSPARENT),
                floatArrayOf(0f, 0.34f, 1f),
                Shader.TileMode.CLAMP,
            )
            this.alpha = (alpha.coerceIn(0.0, 1.0) * 0.28 * 255).toInt()
            xfermode = PorterDuffXfermode(PorterDuff.Mode.ADD)
        }
        canvas.drawCircle((width * light.x).toFloat(), (height * (1 - light.y)).toFloat(), radius, paint)
    }

    private fun particlePaint(preset: RemoteParticlePreset, alpha: Double, pixel: Boolean): Paint {
        val (red, green, blue, base) = when (preset) {
            RemoteParticlePreset.rain -> Quad(0.60f, 0.77f, 0.94f, 0.48f)
            RemoteParticlePreset.ember -> Quad(1f, 0.42f, 0.10f, 0.92f)
            RemoteParticlePreset.smoke -> Quad(0.63f, 0.68f, 0.76f, 0.17f)
            RemoteParticlePreset.firefly -> Quad(0.84f, 0.95f, 0.44f, 0.95f)
            RemoteParticlePreset.snow -> Quad(0.92f, 0.92f, 0.92f, 0.82f)
            RemoteParticlePreset.bubble -> Quad(0.55f, 0.88f, 1f, 0.35f)
            RemoteParticlePreset.stardust -> Quad(0.76f, 0.85f, 1f, 0.9f)
        }
        return Paint(if (pixel) 0 else Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb((base * 255).toInt(), (red * 255).toInt(), (green * 255).toInt(), (blue * 255).toInt())
            this.alpha = (alpha.coerceIn(0.0, 1.0) * base * 255).toInt()
        }
    }

    private fun bitmap(context: Context, theme: Theme, asset: String): Bitmap? {
        val file = theme.localAssets[asset]?.let(::File)?.takeIf(File::isFile)
            ?: theme.remoteContentVersion?.let { RemoteAssetCache.existing(context, it, theme.id, asset) }
        val key = file?.absolutePath ?: "$asset:${theme.artwork}"
        synchronized(bitmaps) { bitmaps.get(key) }?.let { return it }
        val decoded = file?.let { BitmapFactory.decodeFile(it.absolutePath) } ?: run {
            if (asset != "artwork") return null
            val id = context.resources.getIdentifier(theme.artwork.replace("-", "_"), "drawable", context.packageName)
            if (id == 0) null else BitmapFactory.decodeResource(context.resources, id)
        } ?: return null
        synchronized(bitmaps) { bitmaps.put(key, decoded) }
        return decoded
    }

    private fun parseColor(value: String): Int =
        runCatching { Color.parseColor(value) }.getOrDefault(Color.rgb(255, 154, 64))

    private fun wrapped(value: Double): Double {
        val remainder = value % 1.0
        return (remainder + 1.0) % 1.0
    }

    private data class Quad(val red: Float, val green: Float, val blue: Float, val alpha: Float)
}
