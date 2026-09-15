pluginManagement {
  repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
  }
}

dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
  repositories {
    google()
    mavenCentral()
    // The module's AARs: `flutter build aar -o <dir>` writes the Maven
    // repository to <dir>/host/outputs/repo.
    maven { url = uri("${rootDir}/local-repo/host/outputs/repo") }
    // The Flutter engine the AARs depend on.
    maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
  }
}

rootProject.name = "HostApp"

include(":app")
