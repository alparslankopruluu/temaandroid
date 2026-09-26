package com.screenmotion.studio

import android.content.Context
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics

class AppTelemetry(context: Context) {
    private val analytics = FirebaseAnalytics.getInstance(context)
    private val crashlytics = FirebaseCrashlytics.getInstance()

    fun log(event: Event) = analytics.logEvent(event.value, null)

    fun record(operation: String) {
        crashlytics.recordException(IllegalStateException(operation))
    }

    enum class Event(val value: String) {
        APP_OPENED("app_opened"),
        ONBOARDING_VIEWED("onboarding_viewed"),
        ONBOARDING_COMPLETED("onboarding_completed"),
        PAYWALL_VIEWED("pro_paywall_viewed"),
        PURCHASE_COMPLETED("pro_purchase_completed"),
        PURCHASE_FAILED("pro_purchase_failed"),
        RESTORE_COMPLETED("pro_restore_completed"),
        RESTORE_FAILED("pro_restore_failed"),
        EDITOR_VIEWED("editor_viewed"),
        DESIGN_SAVED("design_saved"),
        EXPORT_STARTED("export_started"),
        EXPORT_COMPLETED("export_completed"),
        EXPORT_FAILED("export_failed"),
    }
}
