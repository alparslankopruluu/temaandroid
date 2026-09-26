package com.screenmotion.studio.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.screenmotion.studio.data.LibraryState
import com.screenmotion.studio.data.ScreenMotionRepository
import com.screenmotion.studio.model.SceneConfiguration
import com.screenmotion.studio.model.InstallKind
import com.screenmotion.studio.purchase.PurchasesRepository
import com.screenmotion.studio.FirebaseIdentityService
import com.screenmotion.studio.AppTelemetry
import android.app.Activity
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class MainViewModel(
    private val repository: ScreenMotionRepository,
    private val purchasesRepository: PurchasesRepository,
    private val identityService: FirebaseIdentityService,
    private val telemetry: AppTelemetry,
) : ViewModel() {
    val themes = repository.themes
    val library = repository.library.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5_000),
        LibraryState(),
    )
    val purchases = purchasesRepository.state

    init {
        telemetry.log(AppTelemetry.Event.APP_OPENED)
        viewModelScope.launch {
            identify()
            purchasesRepository.refresh()
            repository.refreshContent()
        }
    }

    private suspend fun identify() {
        runCatching { purchasesRepository.identify(identityService.userId()) }
            .onFailure { telemetry.record("anonymous_identity_unavailable") }
    }

    fun completeWelcome() = viewModelScope.launch {
        repository.completeWelcome()
        telemetry.log(AppTelemetry.Event.ONBOARDING_COMPLETED)
    }
    fun toggleFavorite(themeId: String) = viewModelScope.launch { repository.toggleFavorite(themeId) }
    fun saveDesign(themeId: String, config: SceneConfiguration) =
        viewModelScope.launch {
            repository.saveDesign(themeId, config)
            telemetry.log(AppTelemetry.Event.DESIGN_SAVED)
        }
    fun deleteDesign(id: String) = viewModelScope.launch { repository.deleteDesign(id) }
    fun markExported(themeId: String, config: SceneConfiguration, kind: InstallKind) =
        viewModelScope.launch {
            repository.markExported(themeId, config, kind)
            telemetry.log(AppTelemetry.Event.EXPORT_COMPLETED)
        }
    fun toggleInstallationStep(themeId: String, config: SceneConfiguration, kind: InstallKind, step: Int) =
        viewModelScope.launch { repository.toggleInstallationStep(themeId, config, kind, step) }
    fun setDebugPro(value: Boolean) = viewModelScope.launch { repository.setDebugPro(value) }
    fun purchase(activity: Activity, id: String) = viewModelScope.launch {
        identify()
        purchasesRepository.purchase(activity, id)
        if (purchasesRepository.state.value.isPro) telemetry.log(AppTelemetry.Event.PURCHASE_COMPLETED)
        else if (purchasesRepository.state.value.error) telemetry.log(AppTelemetry.Event.PURCHASE_FAILED)
    }
    fun restore() = viewModelScope.launch {
        identify()
        purchasesRepository.restore()
        telemetry.log(if (purchasesRepository.state.value.error) AppTelemetry.Event.RESTORE_FAILED else AppTelemetry.Event.RESTORE_COMPLETED)
    }
    fun exportStarted() = telemetry.log(AppTelemetry.Event.EXPORT_STARTED)
    fun exportFinished(success: Boolean) {
        if (!success) telemetry.log(AppTelemetry.Event.EXPORT_FAILED)
    }
    fun screenViewed(screen: String) {
        when (screen) {
            "welcome" -> telemetry.log(AppTelemetry.Event.ONBOARDING_VIEWED)
            "editor" -> telemetry.log(AppTelemetry.Event.EDITOR_VIEWED)
            "paywall" -> telemetry.log(AppTelemetry.Event.PAYWALL_VIEWED)
        }
    }
    fun refreshPurchases() = viewModelScope.launch { purchasesRepository.refresh() }

    class Factory(
        private val repository: ScreenMotionRepository,
        private val purchasesRepository: PurchasesRepository,
        private val identityService: FirebaseIdentityService,
        private val telemetry: AppTelemetry,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            MainViewModel(repository, purchasesRepository, identityService, telemetry) as T
    }
}
