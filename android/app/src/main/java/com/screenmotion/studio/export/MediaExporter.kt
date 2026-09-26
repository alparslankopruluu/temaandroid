package com.screenmotion.studio.export

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.LruCache
import com.screenmotion.studio.model.InteractionProfile
import com.screenmotion.studio.model.SceneConfiguration
import com.screenmotion.studio.model.Theme
import com.screenmotion.studio.model.ThemeCollection
import com.screenmotion.studio.scene.InteractiveSceneBehavior
import com.screenmotion.studio.scene.RemoteMotion
import com.screenmotion.studio.scene.RemoteScenePainter
import com.screenmotion.studio.scene.SceneInput
import com.screenmotion.studio.scene.SceneSnapshot
import com.screenmotion.studio.scene.SceneVector
import java.io.File
import java.io.FileInputStream
import kotlin.concurrent.thread
import kotlin.math.cos
import kotlin.math.sin

object SceneBitmapRenderer {
    private val artworkCache = object : LruCache<Int, Bitmap>(64 * 1024 * 1024) {
        override fun sizeOf(key: Int, value: Bitmap): Int = value.allocationByteCount
    }

    fun render(
        context: Context,
        theme: Theme,
        configuration: SceneConfiguration,
        width: Int,
        height: Int,
        time: Double,
    ): Bitmap {
        require(width in 1..4096 && height in 1..4096)
        val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val behavior = theme.interaction?.let {
            InteractiveSceneBehavior(it, configuration.scoreMode, InteractiveSceneBehavior.seed(theme.id))
        }
        var elapsed = 0.0
        while (elapsed + .000001 < time.coerceAtLeast(0.0)) {
            val delta = minOf(1.0 / 60.0, time - elapsed)
            behavior?.let { advance(it, delta, elapsed + delta) }
            elapsed += delta
        }
        draw(context, Canvas(result), theme, configuration, time, snapshot = behavior?.snapshot())
        return result
    }

    fun advance(behavior: InteractiveSceneBehavior, delta: Double, time: Double) {
        val input = SceneInput(
            tilt = SceneVector(sin(time * .8) * .65, cos(time * .55) * .25),
            tap = if (time >= 1.25 && time - delta < 1.25) SceneVector(.35, .1) else null,
        )
        behavior.update(delta, time, input)
    }

    fun draw(
        context: Context,
        canvas: Canvas,
        theme: Theme,
        configuration: SceneConfiguration,
        time: Double,
        motionX: Float = 0f,
        motionY: Float = 0f,
        snapshot: SceneSnapshot? = null,
        remoteMotion: RemoteMotion? = null,
    ) {
        if (theme.remoteScene != null) {
            RemoteScenePainter.draw(
                context,
                canvas,
                theme,
                configuration,
                time,
                remoteMotion ?: RemoteMotion(
                    displacementX = sin(time * 0.61) * 0.24,
                    displacementY = cos(time * 0.47) * 0.16,
                ),
            )
            return
        }
        val width = canvas.width.toFloat()
        val height = canvas.height.toFloat()
        canvas.drawColor(backgroundColor(theme.interaction))
        val id = context.resources.getIdentifier(theme.artwork.replace("-", "_"), "drawable", context.packageName)
        val source = if (id == 0) null else synchronized(artworkCache) {
            artworkCache.get(id) ?: BitmapFactory.decodeResource(context.resources, id)?.also { artworkCache.put(id, it) }
        }
        if (source != null) {
            val scale = maxOf(width / source.width, height / source.height) *
                configuration.zoom * (1.04f + configuration.depth * .04f)
            val offsetX = sin(time * .7).toFloat() * configuration.intensity * configuration.depth * 18f + motionX * configuration.depth * 28f
            val offsetY = cos(time * .5).toFloat() * configuration.intensity * configuration.depth * 12f + motionY * configuration.depth * 20f
            val matrix = Matrix().apply {
                postScale(scale, scale)
                postTranslate(
                    (width - source.width * scale) / 2f + offsetX,
                    (height - source.height * scale) / 2f + offsetY,
                )
            }
            canvas.drawBitmap(source, matrix, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                isFilterBitmap = !theme.isPixel
            })
        } else {
            drawProgrammatic(canvas, theme, configuration, time)
        }
        if (!theme.isPixel) drawRealisticAccent(canvas, theme, configuration, time)
        val tint = when (configuration.style) {
            1 -> Color.argb(45, 40, 108, 255)
            2 -> Color.argb(45, 255, 122, 34)
            else -> Color.TRANSPARENT
        }
        canvas.drawColor(tint)
        val particlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(48, 255, 255, 255) }
        repeat((36 * configuration.particles).toInt().coerceIn(0, 36)) { index ->
            val phase = index * .618 + time * (.12 + configuration.intensity * .2)
            val x = ((sin(phase) + 1) * .5 * width).toFloat()
            val y = ((cos(phase * 1.31) + 1) * .5 * height).toFloat()
            canvas.drawCircle(x, y, if (theme.isPixel) 5f else 3f, particlePaint)
        }
        if (theme.isPixel) drawPixelPlayer(canvas, theme.interaction, time, snapshot ?: SceneSnapshot())
        if (configuration.scoreMode && theme.supportsScore) {
            drawScoreObstacles(canvas, snapshot ?: SceneSnapshot())
        }
    }

    private fun drawProgrammatic(canvas: Canvas, theme: Theme, configuration: SceneConfiguration, time: Double) {
        val paint = Paint()
        val profile = theme.interaction
        val cellWidth = canvas.width / 7f
        val cellHeight = canvas.height / 6f
        val speed = configuration.intensity.toDouble()
        repeat(42) { index ->
            val phase = index * .618 + time * speed * .22
            val alpha = (90 + 70 * sin(phase)).toInt().coerceIn(24, 180)
            val x = ((index % 7) * cellWidth + (sin(phase) * configuration.depth * 16f)).toFloat()
            val y = ((index / 7) * cellHeight + cos(phase * .7) * configuration.depth * 12f).toFloat()
            paint.color = paletteColor(profile, index, alpha)
            when (profile) {
                InteractionProfile.AQUARIUM, InteractionProfile.KOI, InteractionProfile.FISH -> {
                    val size = cellWidth * (.08f + index % 4 * .025f)
                    canvas.drawOval(RectF(x, y, x + size * 1.7f, y + size), paint)
                    canvas.drawCircle(x + size * 1.2f, y + size * .32f, size * .07f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
                }
                InteractionProfile.SNOW -> {
                    canvas.drawCircle(x, y, cellWidth * (.025f + index % 3 * .006f), paint)
                }
                InteractionProfile.AUTUMN -> {
                    val size = cellWidth * (.06f + index % 3 * .02f)
                    canvas.save()
                    canvas.rotate((sin(phase) * 45).toFloat(), x, y)
                    canvas.drawOval(RectF(x, y, x + size, y + size * .5f), paint)
                    canvas.restore()
                }
                InteractionProfile.RACE -> {
                    val width = if (index % 4 == 0) cellWidth * .75f else cellWidth * .12f
                    canvas.drawRect(x, y, x + width, y + cellHeight * .08f, paint)
                }
                InteractionProfile.UFO -> {
                    if (index % 6 == 0) canvas.drawRect(x, y, x + cellWidth * .28f, y + cellWidth * .28f, paint)
                    else canvas.drawCircle(x, y, cellWidth * (.015f + index % 3 * .007f), paint)
                }
                else -> canvas.drawRect(RectF(x, y, x + cellWidth * .65f, y + cellHeight * .55f), paint)
            }
        }
    }

    private fun backgroundColor(profile: InteractionProfile?): Int = when (profile) {
        InteractionProfile.FISH, InteractionProfile.AQUARIUM, InteractionProfile.KOI -> Color.rgb(5, 24, 61)
        InteractionProfile.UFO -> Color.rgb(10, 5, 40)
        InteractionProfile.RACE -> Color.rgb(42, 8, 11)
        InteractionProfile.AUTUMN -> Color.rgb(54, 19, 8)
        InteractionProfile.SNOW -> Color.rgb(10, 35, 60)
        InteractionProfile.NATURE -> Color.rgb(7, 35, 22)
        else -> Color.rgb(9, 11, 20)
    }

    private fun paletteColor(profile: InteractionProfile?, index: Int, alpha: Int): Int {
        val colors = when (profile) {
            InteractionProfile.FISH, InteractionProfile.AQUARIUM -> intArrayOf(Color.rgb(35, 191, 202), Color.rgb(88, 124, 221), Color.rgb(51, 222, 169))
            InteractionProfile.KOI -> intArrayOf(Color.rgb(255, 156, 55), Color.rgb(245, 242, 217), Color.rgb(28, 58, 88))
            InteractionProfile.UFO -> intArrayOf(Color.rgb(136, 90, 255), Color.rgb(68, 239, 217), Color.rgb(255, 255, 255))
            InteractionProfile.RACE -> intArrayOf(Color.rgb(255, 79, 63), Color.rgb(245, 245, 242), Color.rgb(255, 194, 61))
            InteractionProfile.AUTUMN -> intArrayOf(Color.rgb(255, 120, 35), Color.rgb(198, 62, 24), Color.rgb(252, 190, 64))
            InteractionProfile.SNOW -> intArrayOf(Color.rgb(225, 246, 255), Color.rgb(112, 181, 219), Color.rgb(255, 255, 255))
            else -> intArrayOf(Color.rgb(120, 214, 115), Color.rgb(56, 160, 100), Color.rgb(184, 230, 128))
        }
        return (colors[index % colors.size] and 0x00ffffff) or (alpha.coerceIn(0, 255) shl 24)
    }

    private fun drawPixelPlayer(canvas: Canvas, profile: InteractionProfile?, time: Double, snapshot: SceneSnapshot) {
        val width = canvas.width.toFloat()
        val height = canvas.height.toFloat()
        val unit = minOf(width, height) * .045f
        val centerX = ((snapshot.position.x + 1) * .5 * width).toFloat()
        val centerY = ((1 - (snapshot.position.y + 1) * .5) * height).toFloat()
        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = paletteColor(profile, 0, 255) }
        val detail = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        canvas.save()
        canvas.rotate((snapshot.rotation * 57.2958).toFloat(), centerX, centerY)
        when (profile) {
            InteractionProfile.CAR, InteractionProfile.RACE -> {
                canvas.drawRoundRect(RectF(centerX - unit * 1.3f, centerY - unit * .65f, centerX + unit * 1.3f, centerY + unit * .65f), unit * .2f, unit * .2f, body)
                canvas.drawRect(centerX - unit * .55f, centerY - unit * .45f, centerX + unit * .45f, centerY - unit * .05f, detail)
                for (offset in listOf(-.8f, .72f)) canvas.drawCircle(centerX + unit * offset, centerY + unit * .62f, unit * .27f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK })
            }
            InteractionProfile.MOTORCYCLE -> {
                canvas.drawCircle(centerX - unit, centerY + unit * .6f, unit * .3f, detail)
                canvas.drawCircle(centerX + unit, centerY + unit * .6f, unit * .3f, detail)
                canvas.drawRoundRect(RectF(centerX - unit * .45f, centerY - unit * .2f, centerX + unit * .45f, centerY + unit * .35f), unit * .2f, unit * .2f, body)
            }
            InteractionProfile.HELICOPTER -> {
                canvas.drawRoundRect(RectF(centerX - unit, centerY - unit * .3f, centerX + unit, centerY + unit * .35f), unit * .35f, unit * .35f, body)
                canvas.drawRect(centerX - unit * 1.7f, centerY - unit * .85f, centerX + unit * 1.7f, centerY - unit * .72f, detail)
                canvas.drawRect(centerX + unit, centerY - unit * .02f, centerX + unit * 1.75f, centerY + unit * .08f, detail)
            }
            InteractionProfile.SPACESHIP, InteractionProfile.UFO -> {
                if (profile == InteractionProfile.UFO) {
                    canvas.drawOval(RectF(centerX - unit * 1.35f, centerY - unit * .35f, centerX + unit * 1.35f, centerY + unit * .5f), body)
                    canvas.drawArc(RectF(centerX - unit * .6f, centerY - unit * .75f, centerX + unit * .6f, centerY + unit * .2f), 180f, 180f, true, detail)
                } else {
                    val path = Path().apply { moveTo(centerX, centerY - unit); lineTo(centerX + unit, centerY + unit * .8f); lineTo(centerX, centerY + unit * .45f); lineTo(centerX - unit, centerY + unit * .8f); close() }
                    canvas.drawPath(path, body)
                    canvas.drawCircle(centerX, centerY, unit * .2f, detail)
                }
            }
            InteractionProfile.FISH, InteractionProfile.AQUARIUM, InteractionProfile.KOI -> {
                canvas.drawOval(RectF(centerX - unit, centerY - unit * .5f, centerX + unit, centerY + unit * .5f), body)
                val tail = Path().apply { moveTo(centerX - unit * .8f, centerY); lineTo(centerX - unit * 1.55f, centerY - unit * .55f); lineTo(centerX - unit * 1.55f, centerY + unit * .55f); close() }
                canvas.drawPath(tail, body)
                canvas.drawCircle(centerX + unit * .58f, centerY - unit * .12f, unit * .08f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK })
            }
            InteractionProfile.AUTUMN, InteractionProfile.NATURE -> {
                canvas.save(); canvas.rotate((sin(time) * 25).toFloat(), centerX, centerY)
                canvas.drawOval(RectF(centerX - unit * .75f, centerY - unit * .38f, centerX + unit * .75f, centerY + unit * .38f), body)
                canvas.drawLine(centerX - unit * .65f, centerY, centerX + unit * .65f, centerY, detail)
                canvas.restore()
            }
            InteractionProfile.SNOW -> {
                for (angle in listOf(0f, 60f, 120f)) {
                    canvas.save(); canvas.rotate(angle, centerX, centerY); canvas.drawLine(centerX - unit, centerY, centerX + unit, centerY, detail); canvas.restore()
                }
            }
            else -> canvas.drawCircle(centerX, centerY, unit, body)
        }
        if (snapshot.tapResponse > 0) {
            val pulse = unit * (1.2f + (1 - snapshot.tapResponse.toFloat()) * 1.8f)
            canvas.drawCircle(centerX, centerY, pulse, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb((90 * snapshot.tapResponse).toInt(), 255, 255, 255); style = Paint.Style.STROKE; strokeWidth = maxOf(2f, unit * .08f) })
        }
        canvas.restore()
    }

    private fun drawScoreObstacles(canvas: Canvas, snapshot: SceneSnapshot) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(255, 64, 85) }
        snapshot.obstacles.forEach { obstacle ->
            val cx = ((obstacle.position.x + 1) * .5 * canvas.width).toFloat()
            val cy = ((1 - (obstacle.position.y + 1) * .5) * canvas.height).toFloat()
            val radius = obstacle.radius.toFloat() * minOf(canvas.width, canvas.height) * .5f
            val path = Path().apply { moveTo(cx, cy - radius); lineTo(cx + radius, cy); lineTo(cx, cy + radius); lineTo(cx - radius, cy); close() }
            canvas.drawPath(path, paint)
        }
    }

    private fun drawRealisticAccent(canvas: Canvas, theme: Theme, config: SceneConfiguration, time: Double) {
        val alpha = (150 * config.intensity).toInt().coerceIn(0, 150)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(alpha, 220, 245, 255); style = Paint.Style.STROKE; strokeWidth = maxOf(2f, canvas.width * .002f) }
        val w = canvas.width.toFloat(); val h = canvas.height.toFloat()
        when (theme.id) {
            "helicopter" -> {
                val cx = w * .62f; val cy = h * .38f + sin(time * 2.0).toFloat() * h * .012f
                canvas.drawLine(cx - w * .08f, cy, cx + w * .08f, cy, paint)
                canvas.drawLine(cx + w * .05f, cy + h * .045f, cx + w * .11f, cy + h * .045f, paint)
            }
            "airplane" -> repeat(7) { i ->
                val y = h * (.24f + i * .018f)
                val start = w * (.58f + i * .018f)
                canvas.drawLine(start, y, w * .88f, y + sin(time + i).toFloat() * h * .008f, paint)
            }
            "reef", "jellyfish" -> repeat(5) { i ->
                val x = (i + 1) * w / 6f
                val y = h * (.65f - ((time * .04 + i * .19) % .25).toFloat())
                canvas.drawCircle(x, y, w * .008f, paint)
            }
            "orbit", "nebula", "spaceship" -> {
                repeat(14) { i ->
                    val angle = time * .16 + i * 2.399
                    val radius = w * (.08f + (i % 4) * .018f)
                    val x = w * .5f + cos(angle).toFloat() * radius
                    val y = h * .36f + sin(angle).toFloat() * radius
                    canvas.drawCircle(x, y, w * .003f, paint)
                }
                val bounds = RectF(w * .34f, h * .25f, w * .66f, h * .44f)
                canvas.drawArc(bounds, ((time * 18) % 360).toFloat(), 150f, false, paint)
            }
            "alpine", "forest" -> repeat(12) { i ->
                val phase = time * .16 + i * .73
                val x = w * (.12f + (i % 6) * .15f) + sin(phase).toFloat() * config.depth * w * .018f
                val y = h * (.22f + (i / 6) * .26f) + cos(phase).toFloat() * config.intensity * h * .02f
                val size = w * (.006f + i % 3 * .002f)
                canvas.drawOval(RectF(x - size, y - size * .4f, x + size, y + size * .4f), paint)
            }
            else -> repeat(10) { i ->
                val phase = time * (.3 + config.intensity * .3) + i * .81
                val x = w * (.08f + (i % 5) * .2f) + sin(phase).toFloat() * config.depth * w * .025f
                val y = h * (.2f + (i / 5) * .42f) + cos(phase).toFloat() * config.intensity * h * .025f
                when (theme.collection) {
                    ThemeCollection.VEHICLES -> canvas.drawLine(x - w * .012f, y, x + w * .018f, y, paint)
                    ThemeCollection.OCEAN -> canvas.drawCircle(x, y, w * (.004f + i % 3 * .002f), paint)
                    ThemeCollection.COSMOS -> canvas.drawCircle(x, y, w * (.002f + i % 2 * .002f), paint)
                    ThemeCollection.NATURE -> canvas.drawOval(RectF(x - w * .006f, y - w * .003f, x + w * .006f, y + w * .003f), paint)
                }
            }
        }
    }
}

object MediaExporter {
    private const val WIDTH = 1080
    private const val HEIGHT = 1920
    private const val FPS = 30
    private const val FRAMES = 90

    fun saveStill(context: Context, theme: Theme, configuration: SceneConfiguration, onComplete: (Boolean) -> Unit = {}) {
        thread(name = "screenmotion-still") {
            val success = runCatching {
                val bitmap = SceneBitmapRenderer.render(context, theme, configuration, WIDTH, HEIGHT, 1.5)
                try {
                    val values = ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, "ScreenMotion-" + theme.id + ".jpg")
                        put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                        put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/ScreenMotion")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                    val uri = requireNotNull(context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values))
                    val encoded = context.contentResolver.openOutputStream(uri)?.use { stream ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                    } == true
                    check(encoded)
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    context.contentResolver.update(uri, values, null, null)
                } finally {
                    bitmap.recycle()
                }
            }.isSuccess
            Handler(Looper.getMainLooper()).post { onComplete(success) }
        }
    }

    fun saveVideo(context: Context, theme: Theme, configuration: SceneConfiguration, onComplete: (Boolean) -> Unit = {}) {
        thread(name = "screenmotion-video") {
            val success = runCatching {
                val file = File.createTempFile("screenmotion-", ".mp4", context.cacheDir)
                try {
                    encodeVideo(context, file, theme, configuration)
                    val values = ContentValues().apply {
                        put(MediaStore.Video.Media.DISPLAY_NAME, "ScreenMotion-" + theme.id + ".mp4")
                        put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                        put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/ScreenMotion")
                        put(MediaStore.Video.Media.IS_PENDING, 1)
                    }
                    val uri = requireNotNull(context.contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values))
                    context.contentResolver.openOutputStream(uri)?.use { output ->
                        FileInputStream(file).use { input -> input.copyTo(output) }
                    } ?: error("MediaStore output unavailable")
                    values.clear()
                    values.put(MediaStore.Video.Media.IS_PENDING, 0)
                    context.contentResolver.update(uri, values, null, null)
                } finally {
                    file.delete()
                }
            }.isSuccess
            Handler(Looper.getMainLooper()).post { onComplete(success) }
        }
    }

    internal fun encodeVideo(context: Context, file: File, theme: Theme, configuration: SceneConfiguration) {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, WIDTH, HEIGHT).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 8_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, FPS)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val surface = codec.createInputSurface()
        val muxer = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        codec.start()
        var track = -1
        var muxerStarted = false
        var sampleIndex = 0L
        val info = MediaCodec.BufferInfo()
        val behavior = theme.interaction?.let {
            InteractiveSceneBehavior(it, configuration.scoreMode, InteractiveSceneBehavior.seed(theme.id))
        }
        var elapsed = 0.0
        try {
            repeat(FRAMES) { frame ->
                val canvas = surface.lockCanvas(null)
                val target = frame.toDouble() / FPS
                while (elapsed + .000001 < target) {
                    val delta = minOf(1.0 / 60.0, target - elapsed)
                    behavior?.let { SceneBitmapRenderer.advance(it, delta, elapsed + delta) }
                    elapsed += delta
                }
                SceneBitmapRenderer.draw(
                    context, canvas, theme, configuration, target,
                    snapshot = behavior?.snapshot(),
                )
                surface.unlockCanvasAndPost(canvas)
                drain@ while (true) {
                    val index = codec.dequeueOutputBuffer(info, 0)
                    when {
                        index == MediaCodec.INFO_TRY_AGAIN_LATER -> break@drain
                        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            check(!muxerStarted) { "Encoder output format changed twice" }
                            track = muxer.addTrack(codec.outputFormat)
                            muxer.start()
                            muxerStarted = true
                        }
                        index >= 0 -> {
                            codec.getOutputBuffer(index)?.let { buffer ->
                                if (info.size > 0 && muxerStarted) {
                                    buffer.position(info.offset)
                                    buffer.limit(info.offset + info.size)
                                    info.presentationTimeUs = sampleIndex * 1_000_000L / FPS
                                    muxer.writeSampleData(track, buffer, info)
                                    sampleIndex += 1
                                }
                            }
                            codec.releaseOutputBuffer(index, false)
                        }
                    }
                }
            }
            codec.signalEndOfInputStream()
            var ended = false
            while (!ended) {
                val index = codec.dequeueOutputBuffer(info, 10_000)
                when {
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> if (!muxerStarted) {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                    index >= 0 -> {
                        codec.getOutputBuffer(index)?.let { buffer ->
                            if (info.size > 0 && muxerStarted) {
                                buffer.position(info.offset)
                                buffer.limit(info.offset + info.size)
                                info.presentationTimeUs = sampleIndex * 1_000_000L / FPS
                                muxer.writeSampleData(track, buffer, info)
                                sampleIndex += 1
                            }
                        }
                        ended = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        codec.releaseOutputBuffer(index, false)
                    }
                }
            }
        } finally {
            codec.stop()
            codec.release()
            surface.release()
            if (muxerStarted) muxer.stop()
            muxer.release()
        }
    }

}
