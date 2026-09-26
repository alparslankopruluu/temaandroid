package com.screenmotion.studio.model

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Test
import java.io.File

class CatalogContractTest {
    private val catalog by lazy {
        Json { ignoreUnknownKeys = true }.decodeFromString<CatalogFile>(
            File("src/main/res/raw/catalog.json").readText(),
        )
    }

    @Test fun catalogMatchesApprovedShape() {
        assertEquals(29, catalog.themes.size)
        assertEquals(29, catalog.themes.map(Theme::id).toSet().size)
        assertEquals(16, catalog.themes.count { !it.isPixel })
        assertEquals(13, catalog.themes.count(Theme::isPixel))
        val rainfire = catalog.themes.single { it.id == "pixel-rainfire" }
        assertEquals("emberBurst", rainfire.remoteScene?.interaction?.name)
        assertEquals(listOf("rain", "ember", "smoke"), rainfire.remoteScene?.particles?.map { it.preset.name })
        assertEquals(5, catalog.themes.count(Theme::isFree))
        assertTrue(catalog.themes.all { it.titleKey.isNotBlank() && it.artwork.isNotBlank() })
    }

    @Test fun everyCurrentIosInteractionProfileIsSupported() {
        assertEquals(12, InteractionProfile.entries.size)
        assertEquals(InteractionProfile.entries.toSet(), catalog.themes.mapNotNull(Theme::interaction).toSet())
        assertTrue(catalog.themes.filter { it.interaction in setOf(InteractionProfile.UFO, InteractionProfile.RACE) }
            .all(Theme::supportsScore))
    }

    @Test fun everyCollectionAndInteractionProfileIsRepresented() {
        assertEquals(ThemeCollection.entries.toSet(), catalog.themes.map(Theme::collection).toSet())
        assertEquals(InteractionProfile.entries.toSet(), catalog.themes.mapNotNull(Theme::interaction).toSet())
    }

    @Test fun installationProgressRequiresAnExportAndAllThreeSteps() {
        val progress = InstallationProgress(completedSteps = setOf("WALLPAPER.1", "WALLPAPER.2", "WALLPAPER.3"))
        assertFalse(progress.isInstalled(InstallKind.WALLPAPER))
        val exported = progress.copy(exported = setOf(InstallKind.WALLPAPER))
        assertTrue(exported.isInstalled(InstallKind.WALLPAPER))
        assertFalse(exported.isInstalled(InstallKind.ICONS))
        assertEquals(
            installationKey("pixel-ufo", SceneConfiguration(style = 1)),
            installationKey("pixel-ufo", SceneConfiguration(style = 1)),
        )
        assertNotEquals(
            installationKey("pixel-ufo", SceneConfiguration(style = 1)),
            installationKey("pixel-ufo", SceneConfiguration(style = 2)),
        )
    }
}
