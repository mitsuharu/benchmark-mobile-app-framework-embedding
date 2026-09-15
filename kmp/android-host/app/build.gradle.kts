plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.plugin.compose")
}

android {
  namespace = "com.example.benchmark.kmp.host"
  compileSdk = 37

  defaultConfig {
    applicationId = "com.example.benchmark.kmp.host"
    minSdk = 24
    targetSdk = 36
    versionCode = 1
    versionName = "1.0"

    // Empty means the real GitHub API. The benchmark build passes
    // -PbenchApiBaseUrl=http://10.0.2.2:8787 to reach bench/mock-server.
    val apiBaseUrl = providers.gradleProperty("benchApiBaseUrl").getOrElse("")
    buildConfigField("String", "BENCH_API_BASE_URL", "\"$apiBaseUrl\"")
  }

  buildTypes {
    release {
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      // Signed with the debug key so the release build installs on an emulator.
      signingConfig = signingConfigs.getByName("debug")
    }
  }

  buildFeatures {
    compose = true
    buildConfig = true
  }

  // Robolectric provides Looper/Context, so the host's glue can be covered by
  // plain unit tests instead of instrumentation tests.
  testOptions { unitTests.isIncludeAndroidResources = true }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
}

dependencies {
  // The Compose Multiplatform library. On Android it is plain Jetpack
  // Compose, so the screen shares the host's Compose runtime.
  implementation("com.example.benchmark.kmp:reposearchkit:1.0.0")

  implementation("androidx.core:core-ktx:1.19.0")
  implementation("androidx.activity:activity-compose:1.13.0")
  implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.11.0")
  implementation(platform("androidx.compose:compose-bom:2026.09.00"))
  implementation("androidx.compose.ui:ui")
  implementation("androidx.compose.material3:material3")
  debugImplementation("androidx.compose.ui:ui-tooling")

  testImplementation("junit:junit:4.13.2")
  testImplementation("org.robolectric:robolectric:4.17")
  testImplementation("androidx.test:core:1.7.0")
}
