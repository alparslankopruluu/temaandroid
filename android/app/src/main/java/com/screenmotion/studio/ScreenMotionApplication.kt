package com.screenmotion.studio

import android.app.Application
import com.screenmotion.studio.data.ScreenMotionRepository
import com.screenmotion.studio.purchase.DisabledPurchasesRepository
import com.screenmotion.studio.purchase.PurchasesRepository
import com.screenmotion.studio.purchase.RevenueCatPurchasesRepository

class ScreenMotionApplication : Application() {
    val repository: ScreenMotionRepository by lazy { ScreenMotionRepository(this) }
    val identityService: FirebaseIdentityService by lazy { FirebaseIdentityService() }
    val telemetry: AppTelemetry by lazy { AppTelemetry(this) }
    val purchasesRepository: PurchasesRepository by lazy {
        BuildConfig.REVENUECAT_PUBLIC_KEY.takeIf(String::isNotBlank)
            ?.let { RevenueCatPurchasesRepository(this, it) }
            ?: DisabledPurchasesRepository()
    }
}
