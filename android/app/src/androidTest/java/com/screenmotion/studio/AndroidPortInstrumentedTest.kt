package com.screenmotion.studio

import android.graphics.Color
import android.media.MediaMetadataRetriever
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.screenmotion.studio.export.IconExportService
import com.screenmotion.studio.export.SceneBitmapRenderer
import com.screenmotion.studio.export.MediaExporter
import com.screenmotion.studio.model.CatalogFile
import com.screenmotion.studio.model.SceneConfiguration
import com.screenmotion.studio.model.ThemeCollection
import com.screenmotion.studio.model.InstallKind
import com.screenmotion.studio.model.installationKey
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.flow.first
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.zip.ZipFile
import java.io.File
import com.screenmotion.studio.data.ScreenMotionRepository

@RunWith(AndroidJUnit4::class)
class AndroidPortInstrumentedTest {
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val catalog by lazy {
        context.resources.openRawResource(R.raw.catalog).bufferedReader().use {
            Json { ignoreUnknownKeys = true }.decodeFromString<CatalogFile>(it.readText())
        }
    }

    @Test fun stillRendererProducesRequestedNonBlankFrame() {
        val bitmap = SceneBitmapRenderer.render(context, catalog.themes.first(), SceneConfiguration(), 320, 480, 1.5)
        assertEquals(320, bitmap.width)
        assertEquals(480, bitmap.height)
        val samples = listOf(bitmap.getPixel(10, 10), bitmap.getPixel(160, 240), bitmap.getPixel(300, 460))
        assertTrue(samples.any { it != Color.BLACK && Color.alpha(it) > 0 })
        bitmap.recycle()
    }

    @Test fun sceneConfigurationChangesTheSharedRenderedFrame() {
        val theme = catalog.themes.first()
        val original = SceneBitmapRenderer.render(context, theme, SceneConfiguration(), 240, 360, 1.25)
        val configured = SceneBitmapRenderer.render(
            context,
            theme,
            SceneConfiguration(intensity = .9f, particles = .9f, depth = .9f, zoom = 1.5f, style = 2),
            240,
            360,
            1.25,
        )
        val differs = (0 until 12).any { sample ->
            val x = 20 + sample * 17
            original.getPixel(x, 180) != configured.getPixel(x, 180)
        }
        assertTrue("scene configuration should change the rendered output", differs)
        original.recycle()
        configured.recycle()
    }

    @Test fun iconPackContains24DistinctPngFiles() = runBlocking {
        val hashes = (0 until IconExportService.COUNT).map { index ->
            val bitmap = IconExportService.image(index, ThemeCollection.COSMOS, 128)
            var hash = 1L
            for (y in 0 until bitmap.height step 8) for (x in 0 until bitmap.width step 8) {
                hash = hash * 31 + bitmap.getPixel(x, y)
            }
            bitmap.recycle()
            hash
        }
        assertEquals(24, hashes.toSet().size)
        val archive = IconExportService.export(context, ThemeCollection.COSMOS)
        ZipFile(archive).use { zip ->
            assertEquals(24, zip.entries().asSequence().count())
            assertTrue(zip.entries().asSequence().all { it.name.endsWith(".png") && zip.getInputStream(it).read() != -1 })
        }
        assertNotEquals(0L, archive.length())
    }

    @Test fun videoEncoderProducesPlayableThreeSecondMp4() {
        val file = File(context.cacheDir, "encoder-contract.mp4").apply { delete() }
        MediaExporter.encodeVideo(context, file, catalog.themes.first(), SceneConfiguration())
        assertTrue(file.length() > 16_000)
        val metadata = MediaMetadataRetriever()
        try {
            metadata.setDataSource(file.absolutePath)
            val duration = metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0L
            assertTrue("duration=$duration", duration in 2_800L..3_300L)
            assertEquals("1080", metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH))
            assertEquals("1920", metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT))
        } finally {
            metadata.release()
            file.delete()
        }
    }

    @Test fun libraryPersistsFavoritesAndDeduplicatedDesigns() = runBlocking {
        val repository = ScreenMotionRepository(context)
        val theme = catalog.themes.last()
        if (theme.id in repository.library.first().favorites) repository.toggleFavorite(theme.id)
        repository.toggleFavorite(theme.id)
        repository.saveDesign(theme.id, SceneConfiguration(style = 2))
        repository.saveDesign(theme.id, SceneConfiguration(style = 2))
        val state = repository.library.first()
        assertTrue(theme.id in state.favorites)
        assertEquals(1, state.designs.count { it.themeId == theme.id && it.configuration.style == 2 })
        state.designs.filter { it.themeId == theme.id && it.configuration.style == 2 }.forEach { repository.deleteDesign(it.id) }
    }

    @Test fun perDesignInstallationProgressPersistsAfterExportAndSteps() {
        runBlocking {
        val repository = ScreenMotionRepository(context)
        val themeId = "install-test-" + System.nanoTime()
        val config = SceneConfiguration(intensity = .73f, style = 2)
        repository.toggleInstallationStep(themeId, config, InstallKind.WALLPAPER, 1)
        repository.toggleInstallationStep(themeId, config, InstallKind.WALLPAPER, 2)
        repository.toggleInstallationStep(themeId, config, InstallKind.WALLPAPER, 3)
        assertTrue(repository.library.first().installationProgress[installationKey(themeId, config)]
            ?.isInstalled(InstallKind.WALLPAPER) == false)
        repository.markExported(themeId, config, InstallKind.WALLPAPER)
        val persisted = repository.library.first().installationProgress.getValue(installationKey(themeId, config))
        assertTrue(persisted.isInstalled(InstallKind.WALLPAPER))
        assertFalse(persisted.isInstalled(InstallKind.ICONS))
        }
    }
}
