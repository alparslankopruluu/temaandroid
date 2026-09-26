package com.screenmotion.studio.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val ScreenBackground = Color(0xFF090B0E)
val ScreenSurface = Color(0xFF16181C)
val ScreenAccent = Color(0xFFC2FA6B)
val ScreenMuted = Color(0xFF999FA5)

private val colors = darkColorScheme(
    primary = ScreenAccent,
    onPrimary = Color(0xFF10130B),
    secondary = Color(0xFF62DAEC),
    background = ScreenBackground,
    onBackground = Color.White,
    surface = ScreenSurface,
    onSurface = Color.White,
    onSurfaceVariant = ScreenMuted,
)

@Composable
fun ScreenMotionTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = colors, content = content)
}
