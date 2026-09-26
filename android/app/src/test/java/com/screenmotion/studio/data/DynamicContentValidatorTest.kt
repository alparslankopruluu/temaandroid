package com.screenmotion.studio.data

import com.screenmotion.studio.model.InteractionProfile
import com.screenmotion.studio.model.Theme
import com.screenmotion.studio.model.ThemeAppearance
import com.screenmotion.studio.model.ThemeCollection
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlinx.coroutines.test.runTest
import java.nio.file.Files
import java.util.Locale

class DynamicContentValidatorTest {
    private val base = listOf(
        Theme("a", "theme.a", ThemeCollection.NATURE, "a", true, "leaf", ThemeAppearance.REALISTIC, InteractionProfile.NATURE),
        Theme("b", "theme.b", ThemeCollection.COSMOS, "b", false, "star", ThemeAppearance.PIXEL, InteractionProfile.SPACESHIP),
    )

    @Test fun acceptsOwnedItemsAndCannotCreateNewOnes() {
        val manifest = DynamicContentValidator.decode(json("a"), "1.0", base.map(Theme::id).toSet())
        assertEquals(listOf("a", "b"), DynamicContentValidator.apply(manifest, base).map(Theme::id))
        assertThrows(IllegalArgumentException::class.java) {
            DynamicContentValidator.decode(json("unknown"), "1.0", base.map(Theme::id).toSet())
        }
    }

    @Test fun schemaTwoAddsAThemeWithoutGrantingExistingIds() {
        val manifest = DynamicContentValidator.decode(themeJson(), "1.0.2", emptySet())
        val merged = DynamicContentValidator.merge(manifest, base, Locale.ENGLISH)
        assertEquals(listOf("pixel-cabin", "a", "b"), merged.map(Theme::id))
        assertEquals("Rain Cabin", merged.first().titleOverride)
        assertEquals(false, merged.first().isFree)
        assertThrows(IllegalArgumentException::class.java) {
            DynamicContentValidator.decode(themeJson().replace("\"schemaVersion\":2", "\"schemaVersion\":1"), "1.0.2", emptySet())
        }
    }

    @Test fun rejectsUnsafeUrlsAndPaths() {
        assertTrue(DynamicContentValidator.isSafeHttps("https://cdn.example.com/public/v1/"))
        assertFalse(DynamicContentValidator.isSafeHttps("http://cdn.example.com/public/v1/"))
        assertFalse(DynamicContentValidator.isSafeHttps("https://user@cdn.example.com/a"))
        assertThrows(IllegalArgumentException::class.java) {
            DynamicContentValidator.decode(json("a").replace("art/a.png", "../secret"), "1.0", setOf("a"))
        }
    }

    @Test fun remoteFailureUsesLastKnownGoodCache() = runTest {
        val cache = Files.createTempDirectory("screenmotion-content").resolve("cache.json").toFile()
        cache.writeText(json("a"))
        val service = DynamicContentService(
            bundledData = json("a").replace("\"contentVersion\":\"2\"", "\"contentVersion\":\"1\""),
            remoteManifestURL = "https://cdn.example.com/manifest.json",
            cacheFile = cache,
            currentAppVersion = "1.0",
            ownedIds = setOf("a"),
            loader = RemoteManifestLoader { error("offline") },
        )
        assertEquals(DynamicContentSource.CACHE, service.load().source)
    }

    @Test fun validRemoteBecomesLastKnownGood() = runTest {
        val cache = Files.createTempDirectory("screenmotion-content").resolve("cache.json").toFile()
        val service = DynamicContentService(
            bundledData = json("a").replace("\"contentVersion\":\"2\"", "\"contentVersion\":\"1\""),
            remoteManifestURL = "https://cdn.example.com/manifest.json",
            cacheFile = cache,
            currentAppVersion = "1.0",
            ownedIds = setOf("a"),
            loader = RemoteManifestLoader { json("a") },
        )
        assertEquals(DynamicContentSource.REMOTE, service.load().source)
        assertTrue(cache.isFile)
    }

    private fun themeJson() = """{
      "schemaVersion":2,"contentVersion":"2","minimumAppVersion":"1.0.2",
      "assetBaseURL":"https://cdn.example.com/v2/","items":[],
      "themes":[{"id":"pixel-cabin","localizedText":{"en":{"title":"Rain Cabin","summary":"Rain"}},
      "isVisible":true,"order":4,"accessPolicy":"pro","appearance":"pixel","collection":"nature",
      "symbol":"house.fill","assets":{"artwork":"assets/2/cabin.png"},
      "scene":{"layers":[{"asset":"artwork","parallax":0.5,"animation":"drift","amount":0.2,"period":12}],
      "particles":[{"preset":"rain","count":8,"speed":0.5}],"interaction":"none","ambientAudioAsset":null}}]
    }""".trimIndent()

    private fun json(id: String) = """{
      "schemaVersion":1,"contentVersion":"2","minimumAppVersion":"1.0",
      "assetBaseURL":"https://cdn.example.com/public/v1/",
      "items":[{"id":"$id","localizedText":{"en":{"title":"Title"}},"isVisible":true,
      "order":2,"accessPolicy":"pro","assets":{"artwork":"art/a.png"}}]
    }""".trimIndent()
}
