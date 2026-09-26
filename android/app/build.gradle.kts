plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.compose.compiler)
  alias(libs.plugins.kotlin.serialization)
  alias(libs.plugins.google.services)
  alias(libs.plugins.firebase.crashlytics)
}

val revenueCatPublicKey = providers.gradleProperty("SCREENMOTION_REVENUECAT_PUBLIC_KEY").orElse("").get()
val uploadStoreFile = providers.environmentVariable("SCREENMOTION_UPLOAD_STORE_FILE").orNull
val uploadStorePassword = providers.environmentVariable("SCREENMOTION_UPLOAD_STORE_PASSWORD").orNull
val uploadKeyPassword = providers.environmentVariable("SCREENMOTION_UPLOAD_KEY_PASSWORD").orNull
val uploadSigningConfigured = listOf(uploadStoreFile, uploadStorePassword, uploadKeyPassword).all { !it.isNullOrBlank() }

android {
    namespace = "com.screenmotion.studio"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.screenmotion.studio"
        minSdk = 26
        targetSdk = 36
        buildConfigField("String", "REVENUECAT_PUBLIC_KEY", "\"${revenueCatPublicKey.replace("\\", "\\\\").replace("\"", "\\\"")}\"")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        versionCode = 2
        versionName = "1.0.2"
        buildConfigField(
            "String",
            "REMOTE_CONTENT_MANIFEST_URL",
            "\"https://screenmotion-dev.web.app/v2/manifest.json\"",
        )
    }

    signingConfigs {
        if (uploadSigningConfigured) {
            create("upload") {
                storeFile = file(requireNotNull(uploadStoreFile))
                storePassword = requireNotNull(uploadStorePassword)
                keyAlias = "screenmotion-upload"
                keyPassword = requireNotNull(uploadKeyPassword)
            }
        }
    }
    buildTypes {
        release {
            buildConfigField(
                "String",
                "REMOTE_CONTENT_MANIFEST_URL",
                "\"https://screenmotion-prod.web.app/v2/manifest.json\"",
            )
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (uploadSigningConfigured) signingConfig = signingConfigs.getByName("upload")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
      compose = true
      aidl = false
      buildConfig = true
      shaders = false
    }

    packaging {
      resources {
        excludes += "/META-INF/{AL2.0,LGPL2.1}"
      }
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
  val composeBom = platform(libs.androidx.compose.bom)
  implementation(composeBom)
  androidTestImplementation(composeBom)

  // Core Android dependencies
  implementation(libs.androidx.core.ktx)
  implementation(libs.androidx.lifecycle.runtime.ktx)
  implementation(libs.androidx.activity.compose)

  // Arch Components
  implementation(libs.androidx.lifecycle.runtime.compose)
  implementation(libs.androidx.lifecycle.viewmodel.compose)

  // Compose
  implementation(libs.androidx.compose.ui)
  implementation(libs.androidx.compose.ui.tooling.preview)
  implementation(libs.androidx.compose.material3)
  // Tooling
  debugImplementation(libs.androidx.compose.ui.tooling)
  // Instrumented tests
  androidTestImplementation(libs.androidx.compose.ui.test.junit4)
  debugImplementation(libs.androidx.compose.ui.test.manifest)

  // Local tests: jUnit, coroutines, Android runner
  testImplementation(libs.junit)
  testImplementation(libs.kotlinx.coroutines.test)

  // Instrumented tests: jUnit rules and runners
  androidTestImplementation(libs.androidx.test.core)
  androidTestImplementation(libs.androidx.test.ext.junit)
  androidTestImplementation(libs.androidx.test.runner)
  androidTestImplementation(libs.androidx.test.espresso.core)

  implementation(libs.androidx.datastore.preferences)
  implementation(libs.kotlinx.serialization.json)
  implementation(libs.revenuecat.purchases)
  implementation(platform(libs.firebase.bom))
  implementation(libs.firebase.auth)
  implementation(libs.firebase.analytics)
  implementation(libs.firebase.crashlytics)
  implementation(libs.kotlinx.coroutines.play.services)
}
