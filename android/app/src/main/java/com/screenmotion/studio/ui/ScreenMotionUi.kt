package com.screenmotion.studio.ui

import android.app.WallpaperManager
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.MediaPlayer
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.graphics.asImageBitmap
import java.io.File
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.screenmotion.studio.R
import com.screenmotion.studio.BuildConfig
import com.screenmotion.studio.model.AppearanceFilter
import com.screenmotion.studio.model.MainTab
import com.screenmotion.studio.model.SavedDesign
import com.screenmotion.studio.model.SceneConfiguration
import com.screenmotion.studio.model.InstallKind
import com.screenmotion.studio.model.InstallationProgress
import com.screenmotion.studio.model.installationKey
import com.screenmotion.studio.model.Theme
import com.screenmotion.studio.model.ThemeAppearance
import com.screenmotion.studio.model.ThemeCollection
import com.screenmotion.studio.scene.SceneRenderer
import com.screenmotion.studio.wallpaper.ScreenMotionWallpaperService
import com.screenmotion.studio.purchase.PurchaseState
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import kotlinx.coroutines.Job

private sealed interface Destination {
    data object Home : Destination
    data class Editor(val theme: Theme, val initial: SceneConfiguration = SceneConfiguration()) : Destination
    data class Export(val theme: Theme, val configuration: SceneConfiguration) : Destination
    data class Package(val collection: ThemeCollection) : Destination
    data object Paywall : Destination
    data class Install(
        val section: String,
        val theme: Theme? = null,
        val configuration: SceneConfiguration? = null,
    ) : Destination
}

@Composable
fun ScreenMotionApp(model: MainViewModel, deepLinkThemeId: String?, consumeDeepLink: () -> Unit) {
    val library by model.library.collectAsStateWithLifecycle()
    val purchases by model.purchases.collectAsStateWithLifecycle()
    val themes by model.themes.collectAsStateWithLifecycle()
    val effectiveLibrary = library.copy(isPro = library.isPro || purchases.isPro)
    var destination by remember { mutableStateOf<Destination>(Destination.Home) }
    LaunchedEffect(library.welcomeComplete, destination) {
        when {
            !library.welcomeComplete -> model.screenViewed("welcome")
            destination is Destination.Editor -> model.screenViewed("editor")
            destination == Destination.Paywall -> model.screenViewed("paywall")
        }
    }
    LaunchedEffect(deepLinkThemeId) {
        themes.firstOrNull { it.id == deepLinkThemeId }?.let { destination = Destination.Editor(it) }
        if (deepLinkThemeId != null) consumeDeepLink()
    }
    if (!library.welcomeComplete) {
        WelcomeScreen(themes.first(), model::completeWelcome)
        return
    }
    when (val current = destination) {
        Destination.Home -> HomeTabs(model, themes, effectiveLibrary) { destination = it }
        is Destination.Editor -> EditorScreen(
            current.theme,
            current.initial,
            current.theme.id in effectiveLibrary.favorites,
            { model.toggleFavorite(current.theme.id) },
            {
                model.saveDesign(current.theme.id, it)
                destination = Destination.Export(current.theme, it)
            },
            { destination = Destination.Home },
        )
        is Destination.Export -> ExportScreen(
            current.theme,
            current.configuration,
            effectiveLibrary.isPro || current.theme.isFree,
            { destination = Destination.Paywall },
            { destination = Destination.Install("wallpaper", current.theme, current.configuration) },
            model::exportStarted,
            model::exportFinished,
            { kind -> model.markExported(current.theme.id, current.configuration, kind) },
            { destination = Destination.Editor(current.theme, current.configuration) },
        )
        is Destination.Package -> PackageScreen(
            current.collection,
            themes.filter { it.collection == current.collection },
            effectiveLibrary.isPro,
            effectiveLibrary.designs,
            { destination = Destination.Paywall },
            { theme, config, kind -> model.markExported(theme.id, config, kind) },
            { destination = Destination.Home },
        )
        Destination.Paywall -> PaywallScreen(
            effectiveLibrary.isPro,
            purchases,
            { model.setDebugPro(true) },
            model::purchase,
            model::restore,
            model::refreshPurchases,
            { destination = Destination.Home },
        )
        is Destination.Install -> {
            val design = effectiveLibrary.designs.firstOrNull()
            val theme = current.theme ?: design?.let { saved -> themes.firstOrNull { it.id == saved.themeId } }
                ?: themes.firstOrNull()
            val config = current.configuration ?: design?.configuration ?: SceneConfiguration()
            val progress = theme?.let { effectiveLibrary.installationProgress[installationKey(it.id, config)] }
                ?: InstallationProgress()
            InstallScreen(
                current.section,
                theme,
                config,
                progress,
                { kind, step -> theme?.let { model.toggleInstallationStep(it.id, config, kind, step) } },
            ) { destination = Destination.Home }
        }
    }
}

@Composable
private fun WelcomeScreen(theme: Theme, complete: () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        SceneRenderer(theme, SceneConfiguration(), Modifier.fillMaxSize())
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .35f)))
        Column(
            Modifier.fillMaxSize().padding(24.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.Bottom,
        ) {
            Text(l("welcome.title"), fontSize = 42.sp, lineHeight = 44.sp, fontWeight = FontWeight.Black)
            Spacer(Modifier.height(12.dp))
            Text(l("welcome.subtitle"), style = MaterialTheme.typography.bodyLarge)
            Spacer(Modifier.height(20.dp))
            PrimaryButton(l("welcome.start"), complete)
            TextButton(complete, Modifier.align(Alignment.CenterHorizontally)) { Text(l("action.skip")) }
            Text(l("welcome.note"), color = ScreenMuted, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun HomeTabs(
    model: MainViewModel,
    themes: List<Theme>,
    library: com.screenmotion.studio.data.LibraryState,
    open: (Destination) -> Unit,
) {
    val context = LocalContext.current
    var tab by remember { mutableStateOf(MainTab.DISCOVER) }
    Scaffold(
        bottomBar = {
            NavigationBar(Modifier.navigationBarsPadding()) {
                MainTab.entries.forEach { item ->
                    val key = when (item) {
                        MainTab.DISCOVER -> "tab.discover"
                        MainTab.LIBRARY -> "tab.library"
                        MainTab.SETTINGS -> "tab.settings"
                    }
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = { tab = item },
                        icon = { Text(if (tab == item) "●" else "○") },
                        label = { Text(l(key)) },
                    )
                }
            }
        },
    ) { padding ->
        when (tab) {
            MainTab.DISCOVER -> DiscoverScreen(
                themes,
                library.favorites,
                { open(Destination.Editor(it)) },
                { open(Destination.Package(it)) },
                Modifier.padding(padding),
            )
            MainTab.LIBRARY -> LibraryScreen(
                themes,
                library,
                { theme, config -> open(Destination.Editor(theme, config)) },
                model::deleteDesign,
                { theme, config, section -> open(Destination.Install(section, theme, config)) },
                Modifier.padding(padding),
            )
            MainTab.SETTINGS -> SettingsScreen(
                library.isPro,
                { open(Destination.Paywall) },
                { open(Destination.Install(it)) },
                Modifier.padding(padding),
            )
        }
    }
}

@Composable
private fun DiscoverScreen(
    themes: List<Theme>,
    favorites: Set<String>,
    openEditor: (Theme) -> Unit,
    openPackage: (ThemeCollection) -> Unit,
    modifier: Modifier,
) {
    val context = LocalContext.current
    var query by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf(AppearanceFilter.ALL) }
    var collection by remember { mutableStateOf<ThemeCollection?>(null) }
    val filtered = themes.filter { theme ->
        val appearanceMatches = when (filter) {
            AppearanceFilter.ALL -> true
            AppearanceFilter.REALISTIC -> theme.appearance == ThemeAppearance.REALISTIC
            AppearanceFilter.PIXEL -> theme.appearance == ThemeAppearance.PIXEL
        }
        appearanceMatches && (collection == null || theme.collection == collection) &&
            (query.isBlank() || titleOf(context, theme).contains(query, true) || theme.subtitleOverride.orEmpty().contains(query, true))
    }
    LazyColumn(
        modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            Text(l("discover.featured"), color = ScreenAccent, fontWeight = FontWeight.Bold)
            Text(l("discover.title"), fontSize = 36.sp, fontWeight = FontWeight.Black)
        }
        item { ThemeHero(themes.first(), themes.first().id in favorites, openEditor) }
        item {
            TextField(
                query,
                { query = it },
                Modifier.fillMaxWidth(),
                placeholder = { Text(l("search.placeholder")) },
                singleLine = true,
            )
        }
        item {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(AppearanceFilter.entries) { item ->
                    FilterChip(
                        selected = filter == item,
                        onClick = { filter = item },
                        label = {
                            Text(l(when (item) {
                                AppearanceFilter.ALL -> "filter.all"
                                AppearanceFilter.REALISTIC -> "filter.realistic"
                                AppearanceFilter.PIXEL -> "filter.pixel"
                            }))
                        },
                    )
                }
            }
        }
        item {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                item { FilterChip(collection == null, { collection = null }, label = { Text(l("filter.all")) }) }
                items(ThemeCollection.entries) { item ->
                    FilterChip(
                        selected = collection == item,
                        onClick = { collection = item },
                        label = { Text(l("collection." + item.name.lowercase())) },
                    )
                }
            }
        }
        item { Text(l("discover.curated"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(filtered.chunked(2)) { group ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                group.forEach { theme ->
                    Box(Modifier.weight(1f)) { ThemeCard(theme, theme.id in favorites, openEditor) }
                }
                if (group.size == 1) Spacer(Modifier.weight(1f))
            }
        }
        item { Text(l("discover.complete"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(ThemeCollection.entries) { item ->
            SurfaceCard(Modifier.clickable { openPackage(item) }) {
                Text(l("collection." + item.name.lowercase()), style = MaterialTheme.typography.titleMedium)
                Text(l("package.subtitle"), color = ScreenMuted)
            }
        }
    }
}

@Composable
private fun ThemeHero(theme: Theme, favorite: Boolean, open: (Theme) -> Unit) {
    Box(Modifier.fillMaxWidth().aspectRatio(.82f).clip(RoundedCornerShape(28.dp)).clickable { open(theme) }) {
        ThemeArtwork(theme, Modifier.fillMaxSize())
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .18f)))
        Column(Modifier.align(Alignment.BottomStart).padding(20.dp)) {
            Text(themeTitle(theme), fontSize = 30.sp, fontWeight = FontWeight.Black)
            Text(if (favorite) "♥" else "♡", color = ScreenAccent, fontSize = 24.sp)
        }
    }
}

@Composable
private fun ThemeCard(theme: Theme, favorite: Boolean, open: (Theme) -> Unit) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(ScreenSurface).clickable { open(theme) }) {
        Box(Modifier.fillMaxWidth().aspectRatio(.72f)) {
            ThemeArtwork(theme, Modifier.fillMaxSize())
            if (!theme.isFree) Text(l("android_pro_badge"), Modifier.align(Alignment.TopEnd).padding(10.dp), color = ScreenAccent)
        }
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(themeTitle(theme), Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(if (favorite) "♥" else "♡", color = ScreenAccent)
        }
    }
}

@Composable
private fun ThemeArtwork(theme: Theme, modifier: Modifier) {
    val context = LocalContext.current
    val remote = remember(theme.id, theme.localAssets["artwork"]) {
        theme.localAssets["artwork"]?.let(::File)?.takeIf(File::isFile)?.let { BitmapFactory.decodeFile(it.absolutePath) }
    }
    val id = remember(theme.artwork) {
        context.resources.getIdentifier(theme.artwork.replace("-", "_"), "drawable", context.packageName)
    }
    if (remote != null) {
        Image(remote.asImageBitmap(), null, modifier, contentScale = ContentScale.Crop)
    } else if (id != 0) {
        Image(painterResource(id), null, modifier, contentScale = ContentScale.Crop)
    } else {
        Canvas(modifier.background(Color(0xFF10273A))) {
            repeat(42) { index ->
                val width = size.width / 7
                val height = size.height / 6
                drawRect(
                    if (theme.collection == ThemeCollection.OCEAN) Color(0x6640DDE8) else Color(0x6678D673),
                    Offset((index % 7) * width, (index / 7) * height),
                    androidx.compose.ui.geometry.Size(width + 1, height + 1),
                )
            }
        }
    }
}

@Composable
private fun EditorScreen(
    theme: Theme,
    initial: SceneConfiguration,
    favorite: Boolean,
    toggleFavorite: () -> Unit,
    save: (SceneConfiguration) -> Unit,
    back: () -> Unit,
) {
    var config by remember(theme.id) { mutableStateOf(initial) }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp, 48.dp, 20.dp, 28.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item { TopBar(themeTitle(theme), back, if (favorite) "♥" else "♡", toggleFavorite) }
        if (theme.remoteScene?.ambientAudioAsset != null) {
            item { ThemeAudioControl(theme) }
        }
        item {
            SceneRenderer(theme, config, Modifier.fillMaxWidth().aspectRatio(.56f).clip(RoundedCornerShape(30.dp)))
        }
        item { Text(l("editor.interact"), color = ScreenMuted) }
        item {
            Text(l("editor.style"), style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("style.original", "style.cool", "style.warm").forEachIndexed { index, key ->
                    FilterChip(config.style == index, { config = config.copy(style = index) }, label = { Text(l(key)) })
                }
            }
        }
        item { ConfigSlider("editor.motion", config.intensity) { config = config.copy(intensity = it) } }
        item { ConfigSlider("editor.particles", config.particles) { config = config.copy(particles = it) } }
        item { ConfigSlider("editor.depth", config.depth) { config = config.copy(depth = it) } }
        item { ConfigSlider("editor.zoom", (config.zoom - 1f) / .6f) { config = config.copy(zoom = 1f + it * .6f) } }
        if (theme.supportsScore) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(l("editor.scoreMode"), Modifier.weight(1f))
                    Switch(config.scoreMode, { config = config.copy(scoreMode = it) })
                }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton({ config = SceneConfiguration() }, Modifier.weight(1f)) { Text(l("action.reset")) }
                Button({ save(config) }, Modifier.weight(2f)) { Text(l("editor.saveInstall")) }
            }
        }
    }
}

@Composable
private fun ConfigSlider(key: String, value: Float, change: (Float) -> Unit) {
    Column {
        Text(l(key))
        Slider(value, change, valueRange = 0f..1f)
    }
}

@Composable
private fun LibraryScreen(
    themes: List<Theme>,
    library: com.screenmotion.studio.data.LibraryState,
    open: (Theme, SceneConfiguration) -> Unit,
    delete: (String) -> Unit,
    install: (Theme, SceneConfiguration, String) -> Unit,
    modifier: Modifier,
) {
    var selected by remember { mutableIntStateOf(0) }
    LazyColumn(modifier.fillMaxSize(), contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Text(l("tab.library"), fontSize = 36.sp, fontWeight = FontWeight.Black)
            Text(l("library.subtitle"), color = ScreenMuted)
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected == 0, { selected = 0 }, label = { Text(l("library.designs")) })
                FilterChip(selected == 1, { selected = 1 }, label = { Text(l("library.favorites")) })
            }
        }
        val empty = if (selected == 0) library.designs.isEmpty() else library.favorites.isEmpty()
        if (empty) item {
            SurfaceCard {
                Text(l("library.empty"), style = MaterialTheme.typography.titleLarge)
                Text(l("library.emptyHint"), color = ScreenMuted)
            }
        }
        if (selected == 0) {
            items(library.designs, key = SavedDesign::id) { design ->
                val theme = themes.firstOrNull { it.id == design.themeId } ?: return@items
                SurfaceCard(Modifier.clickable { open(theme, design.configuration) }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(themeTitle(theme), Modifier.weight(1f))
                        TextButton({ delete(design.id) }) { Text(l("action.delete")) }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                        listOf("wallpaper", "icons", "widgets").forEach { section ->
                            val kind = when (section) {
                                "icons" -> InstallKind.ICONS
                                "widgets" -> InstallKind.WIDGETS
                                else -> InstallKind.WALLPAPER
                            }
                            val key = installationKey(theme.id, design.configuration)
                            val complete = library.installationProgress[key]?.isInstalled(kind) == true
                            TextButton(onClick = { install(theme, design.configuration, section) }) {
                                Text(l(if (complete) "install.completed" else "install.$section"), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                        }
                    }
                }
            }
        } else {
            items(themes.filter { it.id in library.favorites }, key = Theme::id) { theme ->
                SurfaceCard(Modifier.clickable { open(theme, SceneConfiguration()) }) { Text(themeTitle(theme)) }
            }
        }
    }
}

@Composable
private fun SettingsScreen(isPro: Boolean, paywall: () -> Unit, install: (String) -> Unit, modifier: Modifier) {
    LazyColumn(modifier.fillMaxSize(), contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item { Text(l("tab.settings"), fontSize = 36.sp, fontWeight = FontWeight.Black) }
        item {
            SurfaceCard(Modifier.clickable(enabled = !isPro, onClick = paywall)) {
                Text(if (isPro) l("pro.active") else l("pro.unlock"), style = MaterialTheme.typography.titleLarge)
                Text(l("pro.subtitle"), color = ScreenMuted)
            }
        }
        item { Text(l("settings.help"), style = MaterialTheme.typography.titleLarge) }
        items(listOf("wallpaper" to "install.wallpaper", "icons" to "install.icons", "widgets" to "install.widgets")) { item ->
            SurfaceCard(Modifier.clickable { install(item.first) }) { Text(l(item.second)) }
        }
        item {
            Text(l("settings.about"), style = MaterialTheme.typography.titleLarge)
            Text(l("privacy.local"), color = ScreenMuted)
            Text(l("platform.detail"), color = ScreenMuted)
        }
    }
}

@Composable
private fun ExportScreen(
    theme: Theme,
    config: SceneConfiguration,
    unlocked: Boolean,
    paywall: () -> Unit,
    installed: () -> Unit,
    exportStarted: () -> Unit,
    exportFinished: (Boolean) -> Unit,
    onExported: (InstallKind) -> Unit,
    back: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var rewardGranted by remember(theme.id) { mutableStateOf(false) }
    var rewardRunning by remember(theme.id) { mutableStateOf(false) }
    var rewardJob by remember(theme.id) { mutableStateOf<Job?>(null) }
    var exportRunning by remember(theme.id) { mutableStateOf(false) }
    val canExport = unlocked || (BuildConfig.DEBUG && rewardGranted)
    fun complete(success: Boolean) {
        exportRunning = false
        exportFinished(success)
        if (success) {
            if (!unlocked) rewardGranted = false
            onExported(InstallKind.WALLPAPER)
            installed()
        }
    }
    val wallpaperLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) onExported(InstallKind.WALLPAPER)
    }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp, 48.dp, 20.dp, 28.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item { TopBar(l("export.title"), back) }
        item { SceneRenderer(theme, config, Modifier.fillMaxWidth().aspectRatio(.56f).clip(RoundedCornerShape(28.dp))) }
        item { Text(l("export.description"), color = ScreenMuted) }
        item {
            ExportOption(l("export.still"), l("export.hint.still"), canExport && !exportRunning, if (exportRunning) ({}) else paywall) {
                exportRunning = true
                exportStarted()
                com.screenmotion.studio.export.MediaExporter.saveStill(context, theme, config, ::complete)
            }
        }
        item {
            ExportOption(l("export.video"), l("export.hint.video"), canExport && !exportRunning, if (exportRunning) ({}) else paywall) {
                exportRunning = true
                exportStarted()
                com.screenmotion.studio.export.MediaExporter.saveVideo(context, theme, config, ::complete)
            }
        }
        item {
            ExportOption(stringResource(R.string.action_apply_live_wallpaper), stringResource(R.string.android_live_wallpaper_note), canExport && !exportRunning, paywall) {
                com.screenmotion.studio.wallpaper.WallpaperSelection.save(
                    context,
                    theme,
                    config.copy(scoreMode = false),
                )
                if (!unlocked) rewardGranted = false
                wallpaperLauncher.launch(
                    Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).putExtra(
                        WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                        ComponentName(context, ScreenMotionWallpaperService::class.java),
                    ),
                )
            }
        }
        if (BuildConfig.DEBUG && !canExport) {
            item {
                PrimaryButton(if (rewardRunning) l("ad.playing") else l("ad.watch")) {
                    if (!rewardRunning) rewardJob = scope.launch {
                        rewardRunning = true
                        try {
                            delay(3_000)
                            rewardGranted = true
                        } finally {
                            rewardRunning = false
                        }
                    }
                }
            }
            if (rewardRunning) item { OutlinedButton({ rewardJob?.cancel() }, Modifier.fillMaxWidth()) { Text(l("action.cancel")) } }
            item { Text(l("ad.testNotice"), color = ScreenMuted, style = MaterialTheme.typography.bodySmall) }
        }
    }
}

@Composable
private fun ExportOption(title: String, hint: String, unlocked: Boolean, locked: () -> Unit, action: () -> Unit) {
    SurfaceCard(Modifier.clickable { if (unlocked) action() else locked() }) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        Text(hint, color = ScreenMuted)
    }
}

@Composable
private fun PackageScreen(
    collection: ThemeCollection,
    themes: List<Theme>,
    pro: Boolean,
    designs: List<SavedDesign>,
    paywall: () -> Unit,
    onExported: (Theme, SceneConfiguration, InstallKind) -> Unit,
    back: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var exporting by remember { mutableStateOf(false) }
    var selectedTheme by remember(collection) { mutableStateOf(themes.firstOrNull()) }
    var selectedConfiguration by remember(collection) {
        mutableStateOf(
            themes.firstOrNull()?.let { theme -> designs.firstOrNull { it.themeId == theme.id }?.configuration }
                ?: SceneConfiguration(),
        )
    }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp, 48.dp, 20.dp, 28.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item { TopBar(l("collection." + collection.name.lowercase()), back) }
        item { Text(l("package.subtitle"), color = ScreenMuted) }
        items((0 until 24).chunked(4)) { group ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                group.forEach { IconGlyph(it, collection, Modifier.weight(1f)) }
            }
        }
        item {
            PrimaryButton(if (exporting) l("purchase.working") else l("icons.export")) {
                if (!pro) {
                    paywall()
                } else if (!exporting) {
                    exporting = true
                    scope.launch {
                        runCatching { com.screenmotion.studio.export.IconExportService.export(context, collection) }
                            .onSuccess { file ->
                                selectedTheme?.let { onExported(it, selectedConfiguration, InstallKind.ICONS) }
                                com.screenmotion.studio.export.IconExportService.share(context, file)
                            }
                        exporting = false
                    }
                }
            }
        }
        item { Text(l("package.widgets"), style = MaterialTheme.typography.titleLarge) }
        items(listOf("widget.photo", "widget.date", "widget.calendar", "widget.collection")) { key ->
            SurfaceCard { Text(l(key)) }
        }
        item { Text(l("widget.selectionHint"), color = ScreenMuted) }
        item {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(themes, key = Theme::id) { theme ->
                    FilterChip(
                        selected = selectedTheme?.id == theme.id,
                        onClick = {
                            selectedTheme = theme
                            selectedConfiguration = designs.firstOrNull { it.themeId == theme.id }?.configuration ?: SceneConfiguration()
                        },
                        label = { Text(themeTitle(theme), maxLines = 1) },
                    )
                }
            }
        }
        item {
            PrimaryButton(l("widget.select")) {
                if (!pro) paywall() else selectedTheme?.let {
                    com.screenmotion.studio.widget.WidgetSelection.save(context, it, selectedConfiguration)
                    onExported(it, selectedConfiguration, InstallKind.WIDGETS)
                    com.screenmotion.studio.widget.ScreenMotionWidgetReceiver.refreshAll(context)
                }
            }
        }
    }
}

@Composable
private fun IconGlyph(index: Int, collection: ThemeCollection, modifier: Modifier) {
    val tint = when (collection) {
        ThemeCollection.VEHICLES -> Color(0xFFFFA864)
        ThemeCollection.OCEAN -> Color(0xFF62DAEC)
        ThemeCollection.COSMOS -> Color(0xFFA882FF)
        ThemeCollection.NATURE -> ScreenAccent
    }
    Box(modifier.aspectRatio(1f).clip(RoundedCornerShape(18.dp)).background(ScreenSurface), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(34.dp)) {
            val path = Path().apply {
                moveTo(size.width / 2, 0f); lineTo(size.width, size.height / 2)
                lineTo(size.width / 2, size.height); lineTo(0f, size.height / 2); close()
            }
            drawPath(path, tint.copy(alpha = .55f + (index % 4) * .1f))
            drawCircle(Color.White.copy(alpha = .72f), size.minDimension * .09f, center)
        }
    }
}

@Composable
private fun PaywallScreen(
    isPro: Boolean,
    purchases: PurchaseState,
    debugUnlock: () -> Unit,
    purchase: (android.app.Activity, String) -> Unit,
    restore: () -> Unit,
    retry: () -> Unit,
    back: () -> Unit,
) {
    val context = LocalContext.current
    var selected by remember(purchases.options) {
        mutableStateOf(purchases.options.firstOrNull { it.annual }?.id ?: purchases.options.firstOrNull()?.id)
    }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp, 48.dp, 20.dp, 28.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item { TopBar(l("pro.title"), back) }
        item { Text(l("pro.subtitle"), color = ScreenMuted, style = MaterialTheme.typography.titleMedium) }
        items(listOf("pro.benefit.scenes", "pro.benefit.exports", "pro.benefit.packs")) { key ->
            SurfaceCard { Text("✓  " + l(key)) }
        }
        if (purchases.options.isNotEmpty()) {
            items(purchases.options, key = { it.id }) { option ->
                SurfaceCard(Modifier.clickable { selected = option.id }) {
                    Text(if (option.annual) l("pro.yearly") else l("pro.monthly"), style = MaterialTheme.typography.titleMedium)
                    Text(option.localizedPrice)
                    if (option.annual) Text(l("pro.mostPopular"), color = ScreenAccent)
                    Text(if (selected == option.id) "●" else "○", color = ScreenAccent)
                }
            }
        } else {
            item { SurfaceCard { Text(l("pro.yearly")); Text(l("pro.mostPopular"), color = ScreenAccent) } }
            item { SurfaceCard { Text(l("pro.monthly")) } }
        }
        if (purchases.configured && selected != null) {
            item {
                PrimaryButton(if (purchases.loading) l("purchase.working") else if (isPro) l("pro.active") else l("pro.continue")) {
                    val activity = context as? android.app.Activity
                    if (!isPro && !purchases.loading && activity != null) selected?.let { purchase(activity, it) }
                }
            }
            if (purchases.error) item { TextButton(retry) { Text(l("action.retry")) } }
        } else if (BuildConfig.DEBUG) {
            item { PrimaryButton(if (isPro) l("pro.active") else l("pro.continue")) { if (!isPro) debugUnlock() } }
            item { Text(stringResource(R.string.android_debug_purchase_note), color = ScreenMuted, style = MaterialTheme.typography.bodySmall) }
        } else {
            item { Text(stringResource(R.string.android_purchase_unavailable), color = ScreenMuted) }
        }
        item {
            Text(
                l("purchase.restore"),
                color = if (purchases.configured) ScreenAccent else ScreenMuted,
                modifier = Modifier.clickable(enabled = purchases.configured && !purchases.loading, onClick = restore),
            )
        }
    }
}

@Composable
private fun InstallScreen(
    section: String,
    theme: Theme?,
    configuration: SceneConfiguration,
    progress: InstallationProgress,
    onToggleStep: (InstallKind, Int) -> Unit,
    back: () -> Unit,
) {
    val key = when (section) {
        "icons" -> "install.icons"
        "widgets" -> "install.widgets"
        else -> "install.wallpaper"
    }
    val androidSteps = when (section) {
        "icons" -> listOf(R.string.android_install_icons_1, R.string.android_install_icons_2, R.string.android_install_icons_3)
        "widgets" -> listOf(R.string.android_install_widgets_1, R.string.android_install_widgets_2, R.string.android_install_widgets_3)
        else -> listOf(R.string.android_install_wallpaper_1, R.string.android_install_wallpaper_2, R.string.android_install_wallpaper_3)
    }
    val installKind = when (section) {
        "icons" -> InstallKind.ICONS
        "widgets" -> InstallKind.WIDGETS
        else -> InstallKind.WALLPAPER
    }
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp, 48.dp, 20.dp, 28.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item { TopBar(l(key), back) }
        item { Text(l("install.intro"), color = ScreenMuted) }
        item { theme?.let { Text(themeTitle(it), color = ScreenMuted) } }
        item { Text(if (progress.isInstalled(installKind)) l("install.completed") else l("install.mark"), color = ScreenAccent) }
        items(3) { index ->
            val complete = "${installKind.name}.${index + 1}" in progress.completedSteps
            SurfaceCard(Modifier.clickable { onToggleStep(installKind, index + 1) }) {
                Text((index + 1).toString(), color = ScreenAccent, fontWeight = FontWeight.Black)
                Text(stringResource(androidSteps[index]))
                Text(if (complete) l("install.completed") else l("install.mark"), color = ScreenMuted)
            }
        }
        item { Text(stringResource(R.string.huawei_theme_note), color = ScreenMuted) }
    }
}

@Composable
private fun TopBar(title: String, back: () -> Unit, action: String? = null, onAction: () -> Unit = {}) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        TextButton(back) { Text("‹", fontSize = 32.sp) }
        Text(title, Modifier.weight(1f), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        action?.let { TextButton(onAction) { Text(it, fontSize = 24.sp) } }
    }
}

@Composable
private fun PrimaryButton(title: String, action: () -> Unit) {
    Button(
        action,
        Modifier.fillMaxWidth().height(56.dp),
        colors = ButtonDefaults.buttonColors(containerColor = ScreenAccent, contentColor = Color(0xFF10130B)),
    ) { Text(title, fontWeight = FontWeight.Bold) }
}

@Composable
private fun SurfaceCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(ScreenSurface).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
        content = content,
    )
}

@Composable
private fun ThemeAudioControl(theme: Theme) {
    var playing by remember(theme.id) { mutableStateOf(false) }
    val player = remember(theme.id) { MediaPlayer() }
    DisposableEffect(theme.id) {
        onDispose {
            player.stopQuietly()
            player.release()
        }
    }
    OutlinedButton({
        val asset = theme.remoteScene?.ambientAudioAsset
        val file = asset?.let { theme.localAssets[it] }?.let(::File)?.takeIf(File::isFile)
        if (playing) {
            player.stopQuietly()
            playing = false
        } else if (file != null) {
            runCatching {
                player.reset()
                player.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                player.setDataSource(file.absolutePath)
                player.isLooping = true
                player.setVolume(0.72f, 0.72f)
                player.prepare()
                player.start()
                playing = true
            }.onFailure {
                player.stopQuietly()
                playing = false
            }
        }
    }, Modifier.fillMaxWidth()) { Text(l(if (playing) "audio.stop" else "audio.play")) }
}

private fun MediaPlayer.stopQuietly() {
    runCatching { if (isPlaying) stop() }
}

@Composable
private fun themeTitle(theme: Theme): String = titleOf(LocalContext.current, theme)

private fun titleOf(context: android.content.Context, theme: Theme): String =
    theme.titleOverride ?: localized(context, theme.titleKey)

@Composable
private fun l(key: String): String = localized(LocalContext.current, key)

private fun localized(context: android.content.Context, key: String): String {
    val name = key.lowercase().replace(Regex("[^a-z0-9_]"), "_")
    val id = context.resources.getIdentifier(name, "string", context.packageName)
    return if (id == 0) key else context.getString(id)
}
