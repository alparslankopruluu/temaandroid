package com.screenmotion.studio.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.screenmotion.studio.BuildConfig
import com.screenmotion.studio.R
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File
import java.util.Locale
import com.screenmotion.studio.model.CatalogFile
import com.screenmotion.studio.model.SavedDesign
import com.screenmotion.studio.model.SceneConfiguration
import com.screenmotion.studio.model.Theme
import com.screenmotion.studio.model.InstallKind
import com.screenmotion.studio.model.InstallationProgress
import com.screenmotion.studio.model.installationKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.SetSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

private val Context.screenMotionDataStore by preferencesDataStore("screenmotion")

data class LibraryState(
    val welcomeComplete: Boolean = false,
    val favorites: Set<String> = emptySet(),
    val designs: List<SavedDesign> = emptyList(),
    val installationProgress: Map<String, InstallationProgress> = emptyMap(),
    val isPro: Boolean = false,
)

class ScreenMotionRepository(private val context: Context) {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val bundledThemes: List<Theme> = context.resources.openRawResource(R.raw.catalog).bufferedReader().use {
        json.decodeFromString<CatalogFile>(it.readText()).themes
    }
    private val dynamicContent = DynamicContentService(
        bundledData = context.resources.openRawResource(R.raw.remote_content).bufferedReader().use { it.readText() },
        remoteManifestURL = BuildConfig.REMOTE_CONTENT_MANIFEST_URL,
        cacheFile = File(context.cacheDir, "remote-content/last-known-good.json"),
        currentAppVersion = BuildConfig.VERSION_NAME,
        ownedIds = bundledThemes.map(Theme::id).toSet(),
    )
    private val themeState = MutableStateFlow(bundledThemes)
    val themes: StateFlow<List<Theme>> = themeState.asStateFlow()

    suspend fun refreshContent(locale: Locale = Locale.getDefault()) {
        val snapshot = dynamicContent.load()
        val merged = DynamicContentValidator.merge(snapshot.manifest, bundledThemes, locale)
        themeState.value = RemoteAssetCache.materialize(context, snapshot.manifest, merged)
    }

    val library: Flow<LibraryState> = context.screenMotionDataStore.data.map { preferences ->
        LibraryState(
            welcomeComplete = preferences[WELCOME] ?: false,
            favorites = decodeSet(preferences[FAVORITES]),
            designs = decodeDesigns(preferences[DESIGNS]),
            installationProgress = decodeInstallationProgress(preferences[INSTALLATION_PROGRESS]),
            isPro = BuildConfig.DEBUG && (preferences[DEBUG_PRO] ?: false),
        )
    }

    suspend fun completeWelcome() {
        context.screenMotionDataStore.edit { it[WELCOME] = true }
    }

    suspend fun toggleFavorite(themeId: String) {
        context.screenMotionDataStore.edit { preferences ->
            val updated = decodeSet(preferences[FAVORITES]).toMutableSet()
            if (!updated.add(themeId)) updated.remove(themeId)
            preferences[FAVORITES] = json.encodeToString(SetSerializer(String.serializer()), updated)
        }
    }

    suspend fun saveDesign(themeId: String, configuration: SceneConfiguration) {
        context.screenMotionDataStore.edit { preferences ->
            val existing = decodeDesigns(preferences[DESIGNS]).toMutableList()
            val index = existing.indexOfFirst {
                it.themeId == themeId && it.configuration == configuration
            }
            val design = SavedDesign(themeId = themeId, configuration = configuration)
            if (index >= 0) existing[index] = design else existing.add(0, design)
            preferences[DESIGNS] = json.encodeToString(ListSerializer(SavedDesign.serializer()), existing)
        }
    }

    suspend fun deleteDesign(id: String) {
        context.screenMotionDataStore.edit { preferences ->
            val updated = decodeDesigns(preferences[DESIGNS]).filterNot { it.id == id }
            preferences[DESIGNS] = json.encodeToString(ListSerializer(SavedDesign.serializer()), updated)
        }
    }

    suspend fun markExported(themeId: String, configuration: SceneConfiguration, kind: InstallKind) {
        updateInstallationProgress(themeId, configuration) { current ->
            current.copy(exported = current.exported + kind)
        }
    }

    suspend fun toggleInstallationStep(
        themeId: String,
        configuration: SceneConfiguration,
        kind: InstallKind,
        step: Int,
    ) {
        if (step !in 1..3) return
        val stepKey = "$kind.$step"
        updateInstallationProgress(themeId, configuration) { current ->
            current.copy(
                completedSteps = if (stepKey in current.completedSteps) {
                    current.completedSteps - stepKey
                } else {
                    current.completedSteps + stepKey
                },
            )
        }
    }

    private suspend fun updateInstallationProgress(
        themeId: String,
        configuration: SceneConfiguration,
        update: (InstallationProgress) -> InstallationProgress,
    ) {
        val key = installationKey(themeId, configuration)
        context.screenMotionDataStore.edit { preferences ->
            val values = decodeInstallationProgress(preferences[INSTALLATION_PROGRESS]).toMutableMap()
            values[key] = update(values[key] ?: InstallationProgress())
            preferences[INSTALLATION_PROGRESS] = json.encodeToString(
                MapSerializer(String.serializer(), InstallationProgress.serializer()), values,
            )
        }
    }

    suspend fun setDebugPro(value: Boolean) {
        if (!BuildConfig.DEBUG) return
        context.screenMotionDataStore.edit { it[DEBUG_PRO] = value }
    }

    fun theme(id: String?): Theme? = themeState.value.firstOrNull { it.id == id }

    private fun decodeSet(value: String?): Set<String> =
        runCatching {
            json.decodeFromString(SetSerializer(String.serializer()), value.orEmpty())
        }.getOrDefault(emptySet())

    private fun decodeDesigns(value: String?): List<SavedDesign> =
        runCatching {
            json.decodeFromString(ListSerializer(SavedDesign.serializer()), value.orEmpty())
        }.getOrDefault(emptyList())

    private fun decodeInstallationProgress(value: String?): Map<String, InstallationProgress> =
        runCatching {
            json.decodeFromString(MapSerializer(String.serializer(), InstallationProgress.serializer()), value.orEmpty())
        }.getOrDefault(emptyMap())

    companion object {
        private val WELCOME = booleanPreferencesKey("welcome-complete")
        private val FAVORITES = stringPreferencesKey("favorite-theme-ids")
        private val DESIGNS = stringPreferencesKey("saved-designs")
        private val INSTALLATION_PROGRESS = stringPreferencesKey("installation-progress-v1")
        private val DEBUG_PRO = booleanPreferencesKey("debug-pro")
    }
}
