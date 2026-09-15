plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")
  id("org.jetbrains.kotlin.plugin.compose")
}

android {
  namespace = "com.example.sample.expo.brownfield.host"
  compileSdk = 36

  defaultConfig {
    applicationId = "com.example.sample.expo.brownfield.host"
    minSdk = 24
    targetSdk = 36
    versionCode = 1
    versionName = "1.0"

    // Handed to the React Native screen as `apiBaseUrl`. Empty means the real
    // GitHub API. The benchmark build passes
    // -PbenchApiBaseUrl=http://10.0.2.2:8787 to reach bench/mock-server.
    val apiBaseUrl = providers.gradleProperty("benchApiBaseUrl").getOrElse("")
    buildConfigField("String", "BENCH_API_BASE_URL", "\"$apiBaseUrl\"")
  }

  buildTypes {
    release {
      // R8 as in any shipping app; every implementation is measured with it.
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

  // Robolectric provides Looper/Context, so the bridge and the Activity glue
  // can be covered by plain unit tests instead of instrumentation tests.
  testOptions { unitTests.isReturnDefaultValues = true }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlinOptions { jvmTarget = "17" }
}

dependencies {
  // The brownfield library. Coordinates come from `android` in the
  // expo-brownfield plugin config (group : libraryName : version).
  implementation("com.example.sample.expo.brownfield:reposearchkit:1.0.1")

  // BrownfieldActivity extends AppCompatActivity, and the React Native view is
  // hosted through a Fragment, so the host app provides both.
  implementation("androidx.appcompat:appcompat:1.7.0")
  implementation("androidx.fragment:fragment-ktx:1.8.5")

  implementation("androidx.core:core-ktx:1.15.0")
  implementation("androidx.activity:activity-compose:1.9.3")
  implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
  implementation(platform("androidx.compose:compose-bom:2024.10.01"))
  implementation("androidx.compose.ui:ui")
  implementation("androidx.compose.material3:material3")
  debugImplementation("androidx.compose.ui:ui-tooling")

  testImplementation("junit:junit:4.13.2")
  testImplementation("org.robolectric:robolectric:4.16.1")
  testImplementation("androidx.test:core:1.7.0")
}
