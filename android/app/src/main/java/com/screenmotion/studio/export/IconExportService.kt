package com.screenmotion.studio.export

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import androidx.core.content.FileProvider
import com.screenmotion.studio.model.ThemeCollection
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Creates the same 24-item, 512 px geometric icon-pack outcome as the iOS app. */
object IconExportService {
    const val COUNT = 24
    const val SIZE = 512

    suspend fun export(context: Context, collection: ThemeCollection): File = withContext(Dispatchers.IO) {
        val directory = File(context.cacheDir, "icon-packs").apply { mkdirs() }
        val archive = File(directory, "ScreenMotion-${collection.name.lowercase()}.zip")
        ZipOutputStream(FileOutputStream(archive)).use { zip ->
            repeat(COUNT) { index ->
                zip.putNextEntry(ZipEntry("%02d.png".format(index + 1)))
                image(index, collection).compress(Bitmap.CompressFormat.PNG, 100, zip)
                zip.closeEntry()
            }
        }
        archive
    }

    fun share(context: Context, archive: File) {
        val uri = FileProvider.getUriForFile(context, context.packageName + ".files", archive)
        context.startActivity(
            Intent.createChooser(
                Intent(Intent.ACTION_SEND).apply {
                    type = "application/zip"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                },
                null,
            ),
        )
    }

    fun image(index: Int, collection: ThemeCollection, size: Int = SIZE): Bitmap {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val scale = size / 100f
        val accent = when (collection) {
            ThemeCollection.VEHICLES -> Color.rgb(255, 166, 97)
            ThemeCollection.OCEAN -> Color.rgb(107, 230, 224)
            ThemeCollection.COSMOS -> Color.rgb(196, 166, 255)
            ThemeCollection.NATURE -> Color.rgb(184, 230, 161)
        }
        canvas.drawColor(Color.rgb(12, 15, 22))
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = android.graphics.RadialGradient(
                20f * scale, 10f * scale, 85f * scale,
                Color.argb(76, Color.red(accent), Color.green(accent), Color.blue(accent)),
                Color.TRANSPARENT,
                android.graphics.Shader.TileMode.CLAMP,
            )
            canvas.drawRect(0f, 0f, size.toFloat(), size.toFloat(), this)
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = accent
            style = Paint.Style.STROKE
            strokeWidth = 3f * scale
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        fun line(vararg points: Pair<Float, Float>, close: Boolean = false) {
            val path = Path().apply {
                moveTo(points[0].first * scale, points[0].second * scale)
                points.drop(1).forEach { lineTo(it.first * scale, it.second * scale) }
                if (close) close()
            }
            canvas.drawPath(path, paint)
        }
        fun circle(x: Float, y: Float, radius: Float) =
            canvas.drawCircle(x * scale, y * scale, radius * scale, paint)
        fun box(x: Float, y: Float, width: Float, height: Float, radius: Float = 5f) =
            canvas.drawRoundRect(x * scale, y * scale, (x + width) * scale, (y + height) * scale, radius * scale, radius * scale, paint)

        when (index.mod(COUNT)) {
            0 -> line(31f to 27f, 25f to 35f, 28f to 48f, 38f to 61f, 52f to 72f, 65f to 74f, 74f to 65f, 63f to 56f, 57f to 62f, 43f to 53f, 36f to 42f, 42f to 36f, 31f to 27f)
            1 -> { box(25f, 28f, 50f, 37f, 12f); line(36f to 65f, 31f to 75f, 49f to 65f); line(36f to 42f, 64f to 42f); line(36f to 52f, 54f to 52f) }
            2 -> { box(25f, 32f, 50f, 37f); line(27f to 35f, 50f to 52f, 73f to 35f); line(27f to 66f, 40f to 53f); line(73f to 66f, 60f to 53f) }
            3 -> { circle(50f, 50f, 24f); line(58f to 35f, 55f to 55f, 35f to 65f, 45f to 45f, 58f to 35f, close = true) }
            4 -> { box(24f, 35f, 52f, 34f); line(34f to 35f, 39f to 27f, 59f to 27f, 65f to 35f); circle(50f, 51f, 11f); circle(67f, 42f, 1f) }
            5 -> { box(25f, 26f, 50f, 48f); circle(39f, 40f, 5f); line(27f to 66f, 43f to 50f, 54f to 59f, 62f to 48f, 74f to 61f) }
            6 -> { line(42f to 65f, 42f to 32f, 68f to 27f, 68f to 58f); line(43f to 41f, 67f to 36f); circle(35f, 65f, 7f); circle(61f, 58f, 7f) }
            7 -> { circle(50f, 50f, 13f); circle(50f, 50f, 5f); repeat(8) { val a = it * PI / 4; line((50 + cos(a) * 19).toFloat() to (50 + sin(a) * 19).toFloat(), (50 + cos(a) * 25).toFloat() to (50 + sin(a) * 25).toFloat()) } }
            8 -> { box(27f, 29f, 46f, 46f); line(27f to 42f, 73f to 42f); line(38f to 24f, 38f to 34f); line(62f to 24f, 62f to 34f); listOf(51f, 63f).forEach { y -> listOf(38f, 50f, 62f).forEach { x -> circle(x, y, 1f) } } }
            9 -> { circle(50f, 50f, 24f); line(50f to 33f, 50f to 50f, 63f to 57f); circle(50f, 50f, 2f) }
            10 -> { line(25f to 32f, 41f to 26f, 59f to 33f, 75f to 27f, 75f to 68f, 59f to 74f, 41f to 67f, 25f to 73f, close = true); line(41f to 27f, 41f to 67f); line(59f to 33f, 59f to 73f) }
            11 -> { circle(41f, 40f, 12f); box(35f, 49f, 39f, 19f, 9f); line(41f to 20f, 41f to 24f); line(21f to 40f, 25f to 40f); line(25f to 24f, 29f to 28f); line(56f to 24f, 60f to 20f) }
            12 -> { box(29f, 24f, 42f, 52f); listOf(39f, 50f, 61f).forEach { line(39f to it, 61f to it) } }
            13 -> listOf(34f, 50f, 66f).forEach { y -> line(26f to y, 30f to y + 4, 37f to y - 5); line(46f to y, 73f to y) }
            14 -> { line(25f to 71f, 25f to 31f, 43f to 31f, 49f to 39f, 75f to 39f, 75f to 71f, close = true); line(26f to 47f, 74f to 47f) }
            15 -> { line(22f to 28f, 30f to 28f, 39f to 61f, 69f to 61f, 77f to 38f, 34f to 38f); circle(43f, 73f, 4f); circle(65f, 73f, 4f) }
            16 -> { line(50f to 34f, 39f to 28f, 25f to 28f, 25f to 69f, 39f to 69f, 50f to 75f, 61f to 69f, 75f to 69f, 75f to 28f, 61f to 28f, 50f to 34f, 50f to 75f); line(33f to 41f, 42f to 43f); line(58f to 43f, 67f to 41f) }
            17 -> { val path = Path(); path.moveTo(50f * scale, 73f * scale); path.cubicTo(10f * scale, 49f * scale, 22f * scale, 21f * scale, 27f * scale, 36f * scale); path.quadTo(43f * scale, 23f * scale, 50f * scale, 38f * scale); path.quadTo(60f * scale, 23f * scale, 73f * scale, 36f * scale); path.cubicTo(82f * scale, 51f * scale, 66f * scale, 63f * scale, 50f * scale, 73f * scale); canvas.drawPath(path, paint) }
            18 -> { box(24f, 31f, 52f, 39f, 9f); line(44f to 41f, 61f to 51f, 44f to 61f, close = true) }
            19 -> { box(42f, 24f, 16f, 34f, 8f); line(32f to 48f, 32f to 57f, 39f to 66f, 61f to 66f, 68f to 57f, 68f to 48f); line(50f to 66f, 50f to 77f); line(39f to 77f, 61f to 77f) }
            20 -> { box(31f, 23f, 38f, 54f); box(38f, 31f, 24f, 10f, 2f); listOf(51f, 63f).forEach { y -> listOf(40f, 50f, 60f).forEach { x -> circle(x, y, 1f) } } }
            21 -> { circle(50f, 50f, 24f); canvas.drawOval(39f * scale, 26f * scale, 61f * scale, 74f * scale, paint); line(27f to 43f, 73f to 43f); line(27f to 57f, 73f to 57f) }
            22 -> { line(23f to 47f, 50f to 25f, 77f to 47f); line(31f to 41f, 31f to 74f, 69f to 74f, 69f to 41f); line(44f to 74f, 44f to 55f, 56f to 55f, 56f to 74f) }
            else -> line(50f to 24f, 58f to 41f, 77f to 44f, 63f to 58f, 66f to 77f, 50f to 68f, 34f to 77f, 37f to 58f, 23f to 44f, 42f to 41f, close = true)
        }
        return bitmap
    }
}
