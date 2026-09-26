package com.screenmotion.studio.purchase

import android.app.Activity
import android.content.Context
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.awaitLogIn
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class PurchaseOption(
    val id: String,
    val title: String,
    val localizedPrice: String,
    val annual: Boolean,
)

data class PurchaseState(
    val configured: Boolean = false,
    val loading: Boolean = false,
    val isPro: Boolean = false,
    val options: List<PurchaseOption> = emptyList(),
    val error: Boolean = false,
)

interface PurchasesRepository {
    val state: StateFlow<PurchaseState>
    suspend fun refresh()
    suspend fun identify(userId: String)
    suspend fun purchase(activity: Activity, optionId: String)
    suspend fun restore()
}

class DisabledPurchasesRepository : PurchasesRepository {
    override val state = MutableStateFlow(PurchaseState()).asStateFlow()
    override suspend fun refresh() = Unit
    override suspend fun identify(userId: String) = Unit
    override suspend fun purchase(activity: Activity, optionId: String) = Unit
    override suspend fun restore() = Unit
}

class RevenueCatPurchasesRepository(context: Context, apiKey: String) : PurchasesRepository {
    private val purchases = if (Purchases.isConfigured) Purchases.sharedInstance else Purchases.configure(
        PurchasesConfiguration.Builder(context, apiKey).build(),
    )
    private val mutableState = MutableStateFlow(PurchaseState(configured = true))
    override val state = mutableState.asStateFlow()
    private var packages = emptyMap<String, Package>()
    private var identifiedUserId: String? = null

    override suspend fun identify(userId: String) {
        if (identifiedUserId == userId) return
        purchases.awaitLogIn(userId)
        identifiedUserId = userId
    }

    override suspend fun refresh() {
        mutableState.value = mutableState.value.copy(loading = true, error = false)
        runCatching {
            val offering = purchases.awaitOfferings().current
            val info = purchases.awaitCustomerInfo()
            packages = offering?.availablePackages.orEmpty().associateBy(Package::identifier)
            PurchaseState(
                configured = true,
                isPro = info.entitlements.active[ENTITLEMENT]?.isActive == true,
                options = packages.values.sortedByDescending { it.packageType.name.contains("ANNUAL") }.map { item ->
                    PurchaseOption(
                        id = item.identifier,
                        title = item.product.title,
                        localizedPrice = item.product.price.formatted,
                        annual = item.packageType.name.contains("ANNUAL"),
                    )
                },
            )
        }.onSuccess { mutableState.value = it }
            .onFailure { mutableState.value = mutableState.value.copy(loading = false, error = true) }
    }

    override suspend fun purchase(activity: Activity, optionId: String) {
        val selected = packages[optionId] ?: return
        mutableState.value = mutableState.value.copy(loading = true, error = false)
        runCatching { purchases.awaitPurchase(PurchaseParams.Builder(activity, selected).build()) }
            .onSuccess { refresh() }
            .onFailure { mutableState.value = mutableState.value.copy(loading = false, error = true) }
    }

    override suspend fun restore() {
        mutableState.value = mutableState.value.copy(loading = true, error = false)
        runCatching { purchases.awaitRestore() }
            .onSuccess { refresh() }
            .onFailure { mutableState.value = mutableState.value.copy(loading = false, error = true) }
    }

    companion object { const val ENTITLEMENT = "pro" }
}
