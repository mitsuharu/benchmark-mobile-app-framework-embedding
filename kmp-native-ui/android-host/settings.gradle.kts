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
    // The library published by `./gradlew publishToHostApp` in ../shared.
    maven { url = uri("${rootDir}/local-repo") }
  }
}

rootProject.name = "HostApp"

include(":app")
