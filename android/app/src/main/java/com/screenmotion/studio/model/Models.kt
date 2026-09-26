package com.screenmotion.studio.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class CatalogFile(val version: Int, val themes: List<Theme>)

@Serializable
data class Theme(
    val id: String,
    val titleKey: String,
    val collection: ThemeCollection,
    val artwork: String,
    val isFree: Boolean,
    val symbol: String,
    val appearance: ThemeAppearance = ThemeAppearance.REALISTIC,
    val interaction: InteractionProfile? = null,
    val remoteScene: RemoteSceneRecipe? = null,
    val titleOverride: String? = null,
    val subtitleOverride: String? = null,
    @kotlinx.serialization.Transient val localAssets: Map<String, String> = emptyMap(),
    val remoteContentVersion: String? = null,
) {
    val isPixel: Boolean get() = appearance == ThemeAppearance.PIXEL
    val supportsScore: Boolean
        get() = interaction in setOf(
            InteractionProfile.CAR,
            InteractionProfile.MOTORCYCLE,
            InteractionProfile.HELICOPTER,
            InteractionProfile.SPACESHIP,
            InteractionProfile.UFO,
            InteractionProfile.RACE,
        )
}

@Serializable
enum class ThemeCollection {
    @SerialName("vehicles") VEHICLES,
    @SerialName("ocean") OCEAN,
    @SerialName("cosmos") COSMOS,
    @SerialName("nature") NATURE,
}

@Serializable
enum class ThemeAppearance {
    @SerialName("realistic") REALISTIC,
    @SerialName("pixel") PIXEL,
}

@Serializable
enum class InteractionProfile {
    @SerialName("car") CAR,
    @SerialName("motorcycle") MOTORCYCLE,
    @SerialName("helicopter") HELICOPTER,
    @SerialName("spaceship") SPACESHIP,
    @SerialName("fish") FISH,
    @SerialName("nature") NATURE,
    @SerialName("ufo") UFO,
    @SerialName("aquarium") AQUARIUM,
    @SerialName("autumn") AUTUMN,
    @SerialName("race") RACE,
    @SerialName("koi") KOI,
    @SerialName("snow") SNOW,
}

@Serializable
data class SceneConfiguration(
    val intensity: Float = .55f,
    val particles: Float = .45f,
    val depth: Float = .5f,
    val zoom: Float = 1f,
    val style: Int = 0,
    val scoreMode: Boolean = false,
)

@Serializable
data class SavedDesign(
    val id: String = UUID.randomUUID().toString(),
    val themeId: String,
    val configuration: SceneConfiguration,
    val savedAtMillis: Long = System.currentTimeMillis(),
)

enum class AppearanceFilter { ALL, REALISTIC, PIXEL }

enum class MainTab { DISCOVER, LIBRARY, SETTINGS }

@Serializable
enum class ExportKind { STILL, VIDEO, LIVE_WALLPAPER }

@Serializable
enum class InstallKind { WALLPAPER, ICONS, WIDGETS }

@Serializable
data class RemoteSceneRecipe(
    val layers: List<RemoteSceneLayer> = emptyList(),
    val particles: List<RemoteParticleEmitter>? = null,
    val light: RemoteSceneLight? = null,
    val interaction: RemoteTouchResponse = RemoteTouchResponse.none,
    val ambientAudioAsset: String? = null,
)

@Serializable
data class RemoteSceneLayer(
    val asset: String,
    val parallax: Double,
    val animation: RemoteLayerAnimation,
    val amount: Double,
    val period: Double,
)

@Serializable
enum class RemoteLayerAnimation { still, sway, drift, flicker, pulse }

@Serializable
data class RemoteParticleEmitter(
    val preset: RemoteParticlePreset,
    val count: Int,
    val speed: Double,
)

@Serializable
enum class RemoteParticlePreset { rain, ember, smoke, firefly, snow, bubble, stardust }

@Serializable
data class RemoteSceneLight(
    val x: Double,
    val y: Double,
    val color: String,
    val radius: Double,
    val flicker: Double,
    val period: Double,
)

@Serializable
enum class RemoteTouchResponse { none, push, ripple, swirl, emberBurst, bubbleTrail }

@Serializable
data class InstallationProgress(
    val exported: Set<InstallKind> = emptySet(),
    val completedSteps: Set<String> = emptySet(),
) {
    fun isInstalled(kind: InstallKind): Boolean =
        kind in exported && (1..3).all { "$kind.$it" in completedSteps }
}

fun installationKey(themeId: String, configuration: SceneConfiguration): String =
    "$themeId|${configuration.intensity}|${configuration.particles}|${configuration.depth}|" +
        "${configuration.zoom}|${configuration.style}|${configuration.scoreMode}"
