package com.screenmotion.studio.data

import com.screenmotion.studio.model.RemoteParticleEmitter
import com.screenmotion.studio.model.RemoteSceneRecipe
import com.screenmotion.studio.model.Theme
import com.screenmotion.studio.model.ThemeAppearance
import com.screenmotion.studio.model.ThemeCollection
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URI
import java.net.HttpURLConnection
import java.net.URL
import java.io.File
import java.io.ByteArrayOutputStream
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Serializable
data class RemoteContentManifest(
    val schemaVersion: Int,
    val contentVersion: String,
    val minimumAppVersion: String,
    val assetBaseURL: String,
    val items: List<RemoteContentItem> = emptyList(),
    val themes: List<RemoteThemeDefinition> = emptyList(),
)

@Serializable
data class RemoteThemeDefinition(
    val id: String,
    val localizedText: Map<String, Map<String, String>>,
    val isVisible: Boolean,
    val order: Int,
    val accessPolicy: RemoteAccessPolicy,
    val appearance: ThemeAppearance,
    val collection: ThemeCollection,
    val symbol: String,
    val assets: Map<String, String>,
    val scene: RemoteSceneRecipe,
)

@Serializable
data class RemoteContentItem(
    val id: String,
    val localizedText: Map<String, Map<String, String>>,
    val isVisible: Boolean,
    val order: Int,
    val accessPolicy: RemoteAccessPolicy,
    val assets: Map<String, String>,
)

@Serializable
enum class RemoteAccessPolicy { free, pro }

enum class DynamicContentSource { BUNDLED, CACHE, REMOTE }

data class DynamicContentSnapshot(
    val manifest: RemoteContentManifest,
    val source: DynamicContentSource,
)

fun interface RemoteManifestLoader {
    suspend fun load(url: String): String
}

class HttpsRemoteManifestLoader : RemoteManifestLoader {
    override suspend fun load(url: String): String = withContext(Dispatchers.IO) {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 5_000
            connection.readTimeout = 8_000
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("Accept", "application/json")
            connection.connect()
            check(connection.responseCode in 200..299)
            val bytes = connection.inputStream.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8 * 1024)
                while (output.size() <= MAX_MANIFEST_BYTES) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            check(bytes.size <= MAX_MANIFEST_BYTES)
            bytes.decodeToString()
        } finally {
            connection.disconnect()
        }
    }

    companion object { const val MAX_MANIFEST_BYTES = 512 * 1024 }
}

/** Remote failure preserves the last-known-good cache and always falls back to bundled data. */
class DynamicContentService(
    private val bundledData: String,
    private val remoteManifestURL: String?,
    private val cacheFile: File?,
    private val currentAppVersion: String,
    private val ownedIds: Set<String>,
    private val loader: RemoteManifestLoader = HttpsRemoteManifestLoader(),
) {
    suspend fun load(): DynamicContentSnapshot {
        val bundled = DynamicContentValidator.decode(bundledData, currentAppVersion, ownedIds)
        val cached = cacheFile?.takeIf(File::isFile)?.let { file ->
            runCatching { DynamicContentValidator.decode(file.readText(), currentAppVersion, ownedIds) }.getOrNull()
        }
        val url = remoteManifestURL?.takeIf(DynamicContentValidator::isSafeHttps)
            ?: return DynamicContentSnapshot(cached ?: bundled, if (cached == null) DynamicContentSource.BUNDLED else DynamicContentSource.CACHE)
        return runCatching {
            val data = loader.load(url)
            val remote = DynamicContentValidator.decode(data, currentAppVersion, ownedIds)
            cacheFile?.let { file ->
                file.parentFile?.mkdirs()
                val temporary = File(file.parentFile, file.name + ".tmp")
                temporary.writeText(data)
                check(temporary.renameTo(file) || run {
                    temporary.copyTo(file, overwrite = true)
                    temporary.delete()
                    true
                })
            }
            DynamicContentSnapshot(remote, DynamicContentSource.REMOTE)
        }.getOrElse {
            DynamicContentSnapshot(cached ?: bundled, if (cached == null) DynamicContentSource.BUNDLED else DynamicContentSource.CACHE)
        }
    }
}

/** Strictly validates public curation. This boundary never receives or grants purchase state. */
object DynamicContentValidator {
    private val version = Regex("[0-9]+(?:\\.[0-9]+)*")
    private val itemId = Regex("[A-Za-z0-9_-]+")
    private val json = Json { ignoreUnknownKeys = false }

    fun decode(data: String, currentAppVersion: String, ownedIds: Set<String>): RemoteContentManifest {
        val manifest = json.decodeFromString<RemoteContentManifest>(data)
        require(manifest.schemaVersion == 1 || manifest.schemaVersion == 2)
        require(version.matches(manifest.contentVersion) && version.matches(manifest.minimumAppVersion))
        require(compareVersions(currentAppVersion, manifest.minimumAppVersion) >= 0)
        require(isSafeHttps(manifest.assetBaseURL))
        require(manifest.items.map(RemoteContentItem::id).toSet().size == manifest.items.size)
        if (manifest.schemaVersion == 1) require(manifest.themes.isEmpty())
        manifest.items.forEach { item ->
            require(itemId.matches(item.id) && item.id in ownedIds)
            require(item.localizedText.isNotEmpty())
            require(item.localizedText.all { (locale, fields) -> locale.isNotBlank() && fields.isNotEmpty() && fields.all { it.key.isNotBlank() && it.value.isNotBlank() } })
            item.assets.forEach { (name, path) -> require(name.isNotBlank() && isSafeAssetPath(path)) }
        }
        require(manifest.themes.size <= 48)
        require(manifest.themes.map(RemoteThemeDefinition::id).toSet().size == manifest.themes.size)
        manifest.themes.forEach { theme -> validateTheme(manifest, theme) }
        return manifest
    }

    fun merge(manifest: RemoteContentManifest, base: List<Theme>, locale: Locale): List<Theme> {
        val items = manifest.items.associateBy(RemoteContentItem::id)
        val definitions = manifest.themes.associateBy(RemoteThemeDefinition::id)
        val language = locale.language
        val merged = base.mapIndexedNotNull { index, theme ->
            definitions[theme.id]?.let { definition ->
                if (!definition.isVisible) return@mapIndexedNotNull null
                return@mapIndexedNotNull definition.order to themeFrom(definition, theme, manifest, language)
            }
            val item = items[theme.id] ?: return@mapIndexedNotNull (10_000 + index) to theme
            if (!item.isVisible) return@mapIndexedNotNull null
            item.order to theme.copy(isFree = item.accessPolicy == RemoteAccessPolicy.free, titleOverride = localized(item.localizedText, "title", language))
        }.toMutableList()
        val known = base.map(Theme::id).toSet()
        manifest.themes.filter { it.isVisible && it.id !in known }.forEach { definition ->
            merged += definition.order to themeFrom(definition, null, manifest, language)
        }
        return merged.sortedWith(compareBy<Pair<Int, Theme>> { it.first }.thenBy { it.second.id }).map { it.second }
    }

    private fun themeFrom(definition: RemoteThemeDefinition, fallback: Theme?, manifest: RemoteContentManifest, language: String): Theme =
        Theme(
            id = definition.id,
            titleKey = fallback?.titleKey ?: "remote.${definition.id}",
            collection = definition.collection,
            artwork = fallback?.artwork ?: "remote-${definition.id}",
            isFree = definition.accessPolicy == RemoteAccessPolicy.free,
            symbol = definition.symbol,
            appearance = definition.appearance,
            interaction = fallback?.interaction,
            remoteScene = definition.scene,
            titleOverride = localized(definition.localizedText, "title", language),
            subtitleOverride = localized(definition.localizedText, "summary", language),
            remoteContentVersion = manifest.contentVersion,
        )

    private fun localized(text: Map<String, Map<String, String>>, field: String, language: String): String? =
        text[language]?.get(field) ?: text["en"]?.get(field)

    private fun validateTheme(manifest: RemoteContentManifest, theme: RemoteThemeDefinition) {
        require(theme.id.length in 3..48 && theme.id == theme.id.lowercase() && theme.id.all { it.isLowerCase() || it.isDigit() || it == '-' })
        val title = theme.localizedText["en"]?.get("title")
        require(!title.isNullOrBlank() && title.length <= 80)
        require(theme.localizedText.all { (locale, fields) ->
            locale.isNotBlank() && !fields["title"].isNullOrBlank() && fields.all { it.key.isNotBlank() && it.value.isNotBlank() } &&
                (fields["summary"]?.length ?: 0) <= 240
        })
        require(theme.assets["artwork"] != null && theme.assets.size <= 12)
        theme.assets.forEach { (name, path) ->
            require(name.length in 1..32 && name.all { it.isLowerCase() || it.isDigit() || it == '-' || it == '_' })
            require(isVersionedAsset(path, manifest.contentVersion) && isSafeAssetPath(path))
            require(imageExtension(path) || (theme.scene.ambientAudioAsset == name && audioExtension(path)))
        }
        require(imageExtension(theme.assets.getValue("artwork")))
        val scene = theme.scene
        require(scene.layers.isNotEmpty() && scene.layers.size <= 8)
        scene.layers.forEach { layer ->
            require(theme.assets[layer.asset] != null && imageExtension(theme.assets.getValue(layer.asset)))
            require(layer.parallax in -1.0..1.0 && layer.amount in 0.0..1.0 && layer.period in 0.5..90.0)
        }
        scene.particles?.let { emitters ->
            require(emitters.size <= 4 && emitters.sumOf(RemoteParticleEmitter::count) <= 160)
            emitters.forEach { require(it.count in 0..120 && it.speed in 0.0..2.0) }
        }
        scene.light?.let { light ->
            require(light.x in 0.0..1.0 && light.y in 0.0..1.0 && light.radius in 0.0..0.5)
            require(light.flicker in 0.0..1.0 && light.period in 0.5..30.0)
            require(light.color.matches(Regex("#[0-9A-Fa-f]{6}")))
        }
        scene.ambientAudioAsset?.let { name ->
            require(theme.assets[name] != null && audioExtension(theme.assets.getValue(name)))
        }
    }

    fun isSafeAssetPath(path: String): Boolean =
        path.isNotBlank() && !path.startsWith('/') && !path.endsWith('/') && '%' !in path && '\\' !in path &&
            path.split('/').all { it.isNotBlank() && it != "." && it != ".." }

    private fun isVersionedAsset(path: String, contentVersion: String): Boolean {
        val segments = path.split('/')
        return segments.size >= 3 && segments[0] == "assets" && segments[1] == contentVersion
    }

    private fun imageExtension(path: String) = path.substringAfterLast('.').lowercase() in setOf("png", "jpg", "jpeg", "webp")

    private fun audioExtension(path: String) = path.substringAfterLast('.').lowercase() in setOf("m4a", "mp3", "aac")

    fun apply(manifest: RemoteContentManifest, base: List<Theme>): List<Theme> {
        val items = manifest.items.associateBy(RemoteContentItem::id)
        return base.mapIndexedNotNull { index, theme ->
            val item = items[theme.id] ?: return@mapIndexedNotNull (10_000 + index) to theme
            if (!item.isVisible) return@mapIndexedNotNull null
            item.order to theme.copy(isFree = item.accessPolicy == RemoteAccessPolicy.free)
        }.sortedWith(compareBy<Pair<Int, Theme>> { it.first }.thenBy { it.second.id }).map { it.second }
    }

    fun isSafeHttps(value: String): Boolean {
        val uri = runCatching { URI(value) }.getOrNull() ?: return false
        return uri.scheme.equals("https", true) && !uri.host.isNullOrBlank() && uri.userInfo == null && uri.query == null && uri.fragment == null
    }

    private fun compareVersions(left: String, right: String): Int {
        require(version.matches(left) && version.matches(right))
        val a = left.split('.').map(String::toInt)
        val b = right.split('.').map(String::toInt)
        repeat(maxOf(a.size, b.size)) { index ->
            val result = a.getOrElse(index) { 0 }.compareTo(b.getOrElse(index) { 0 })
            if (result != 0) return result
        }
        return 0
    }
}
