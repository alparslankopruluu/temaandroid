package com.screenmotion.studio.data

import android.content.Context
import android.graphics.BitmapFactory
import com.screenmotion.studio.model.RemoteSceneRecipe
import com.screenmotion.studio.model.Theme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

object RemoteAssetCache {
    suspend fun materialize(context: Context, manifest: RemoteContentManifest, themes: List<Theme>): List<Theme> =
        withContext(Dispatchers.IO) {
            val definitions = manifest.themes.associateBy { it.id }
            themes.map { theme ->
                val definition = definitions[theme.id] ?: return@map theme
                val version = manifest.contentVersion
                val files = definition.assets.mapNotNull { (name, path) ->
                    val source = safeAssetUrl(manifest.assetBaseURL, path) ?: return@mapNotNull null
                    val kind = if (name == definition.scene.ambientAudioAsset) AssetKind.AUDIO else AssetKind.IMAGE
                    download(context, source, version, theme.id, name, kind)?.let { name to it.absolutePath }
                }.toMap()
                theme.copy(localAssets = files)
            }
        }

    fun existing(context: Context, version: String, itemId: String, assetName: String): File? {
        val directory = File(context.cacheDir, "remote-content/assets/$version")
        return directory.listFiles()?.firstOrNull { file ->
            file.nameWithoutExtension == "$itemId-$assetName" && file.length() > 0
        }
    }

    private fun download(
        context: Context,
        source: String,
        version: String,
        itemId: String,
        assetName: String,
        kind: AssetKind,
    ): File? {
        if (!safeComponent(version) || !safeComponent(itemId) || !safeComponent(assetName)) return null
        val extension = source.substringAfterLast('.', "").lowercase().substringBefore('?')
        if (extension !in kind.extensions) return null
        val directory = File(context.cacheDir, "remote-content/assets/$version")
        val destination = File(directory, "$itemId-$assetName.$extension")
        if (destination.isFile && usable(destination, kind)) return destination
        val connection = URL(source).openConnection() as HttpURLConnection
        return try {
            connection.connectTimeout = 8_000
            connection.readTimeout = 20_000
            connection.instanceFollowRedirects = false
            connection.connect()
            if (connection.responseCode !in 200..299) return null
            val mime = connection.contentType?.substringBefore(';')?.lowercase()
            if (mime !in kind.mimeTypes) return null
            val bytes = connection.inputStream.use { it.readBytes() }
            if (bytes.size !in 1..kind.maximumBytes || !decodable(bytes, kind)) return null
            directory.mkdirs()
            val temporary = File(directory, destination.name + ".tmp")
            temporary.writeBytes(bytes)
            if (!temporary.renameTo(destination)) temporary.copyTo(destination, overwrite = true).also { temporary.delete() }
            destination.takeIf { usable(it, kind) }
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }

    private fun usable(file: File, kind: AssetKind): Boolean = when (kind) {
        AssetKind.IMAGE -> BitmapFactory.decodeFile(file.absolutePath) != null
        AssetKind.AUDIO -> file.length() > 0
    }

    private fun decodable(bytes: ByteArray, kind: AssetKind): Boolean = when (kind) {
        AssetKind.IMAGE -> BitmapFactory.decodeByteArray(bytes, 0, bytes.size) != null
        AssetKind.AUDIO -> bytes.isNotEmpty()
    }

    private fun safeComponent(value: String): Boolean =
        value.isNotEmpty() && value != "." && value != ".." && value.all { it.isLetterOrDigit() || it == '-' || it == '_' || it == '.' }

    private fun safeAssetUrl(base: String, path: String): String? {
        if (!DynamicContentValidator.isSafeHttps(base) || !DynamicContentValidator.isSafeAssetPath(path)) return null
        return base.trimEnd('/') + "/" + path
    }

    private enum class AssetKind(val maximumBytes: Int, val extensions: Set<String>, val mimeTypes: Set<String>) {
        IMAGE(15_000_000, setOf("png", "jpg", "jpeg", "webp"), setOf("image/png", "image/jpeg", "image/webp")),
        AUDIO(8_000_000, setOf("m4a", "mp3", "aac"), setOf("audio/mp4", "audio/mpeg", "audio/aac", "audio/x-m4a")),
    }
}
