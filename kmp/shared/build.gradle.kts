import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
  id("org.jetbrains.kotlin.multiplatform") version "2.4.20"
  id("org.jetbrains.kotlin.plugin.compose") version "2.4.20"
  id("org.jetbrains.kotlin.plugin.serialization") version "2.4.20"
  id("org.jetbrains.compose") version "1.12.0"
  id("com.android.kotlin.multiplatform.library") version "9.4.0"
  id("maven-publish")
}

group = "com.example.benchmark.kmp"

version = "1.0.0"

kotlin {
  android {
    namespace = "com.example.benchmark.kmp.reposearchkit"
    compileSdk = 37
    minSdk = 24

    // Runs commonTest on the JVM, so Linux CI can test without an emulator.
    withHostTest {}
  }

  // Apple silicon simulators and devices. Intel simulators are not built.
  val xcframework = XCFramework("RepoSearchKit")
  listOf(iosArm64(), iosSimulatorArm64()).forEach { target ->
    target.binaries.framework {
      baseName = "RepoSearchKit"
      // Linked into the host app rather than loaded at launch, like the
      // native baseline's Swift package.
      isStatic = true
      xcframework.add(this)
    }
  }

  sourceSets {
    commonMain.dependencies {
      // Compose Multiplatform 1.12. Material 3 is versioned on its own.
      implementation("org.jetbrains.compose.runtime:runtime:1.12.0")
      implementation("org.jetbrains.compose.foundation:foundation:1.12.0")
      implementation("org.jetbrains.compose.ui:ui:1.12.0")
      implementation("org.jetbrains.compose.material3:material3:1.9.0")

      implementation("io.ktor:ktor-client-core:3.5.2")
      implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.11.0")
      implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")
    }
    androidMain.dependencies { implementation("io.ktor:ktor-client-okhttp:3.5.2") }
    iosMain.dependencies { implementation("io.ktor:ktor-client-darwin:3.5.2") }
    commonTest.dependencies {
      implementation(kotlin("test"))
      implementation("io.ktor:ktor-client-mock:3.5.2")
      implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.11.0")
    }
  }
}

// The Android host resolves the library from this directory, the same way
// the Flutter and Expo hosts consume their AARs.
publishing {
  repositories {
    maven {
      name = "hostAppRepo"
      url = uri("../android-host/local-repo")
    }
  }
}

// What the Android host resolves: the root module, whose Gradle metadata
// points at the Android variant, and the Android variant itself. The iOS
// variants are left out so this also runs on Linux.
tasks.register("publishToHostApp") {
  group = "publishing"
  description = "Publishes the Android library to ../android-host/local-repo."
  dependsOn(
    "publishKotlinMultiplatformPublicationToHostAppRepoRepository",
    "publishAndroidPublicationToHostAppRepoRepository",
  )
}
