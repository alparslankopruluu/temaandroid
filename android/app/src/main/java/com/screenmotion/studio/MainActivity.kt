package com.screenmotion.studio

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.screenmotion.studio.ui.MainViewModel
import com.screenmotion.studio.ui.ScreenMotionApp
import com.screenmotion.studio.ui.ScreenMotionTheme

class MainActivity : ComponentActivity() {
    private var deepLinkThemeId by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        deepLinkThemeId = themeId(intent)
        val repository = (application as ScreenMotionApplication).repository
        val purchasesRepository = (application as ScreenMotionApplication).purchasesRepository
        val identityService = (application as ScreenMotionApplication).identityService
        val telemetry = (application as ScreenMotionApplication).telemetry
        setContent {
            ScreenMotionTheme {
                Surface(Modifier.fillMaxSize()) {
                    val model: MainViewModel = viewModel(factory = MainViewModel.Factory(repository, purchasesRepository, identityService, telemetry))
                    ScreenMotionApp(model, deepLinkThemeId) { deepLinkThemeId = null }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        deepLinkThemeId = themeId(intent)
    }

    private fun themeId(intent: Intent?): String? =
        intent?.data?.takeIf { it.scheme == "screenmotion" && it.host == "theme" }
            ?.pathSegments?.firstOrNull()
}
