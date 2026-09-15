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
  }
}

rootProject.name = "HostApp"

include(":app")

// The search screen, kept in its own module: the same shape the other
// implementations ship their embedded screen in (an AAR next to the host app).
include(":reposearchkit")
