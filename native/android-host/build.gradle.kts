// AGP 9 compiles Kotlin itself (built-in Kotlin), so the modules apply no
// Kotlin Android plugin. Listing the Kotlin compiler plugins here pins the
// Kotlin version that built-in Kotlin uses.
plugins {
  id("com.android.application") version "9.4.0" apply false
  id("com.android.library") version "9.4.0" apply false
  id("org.jetbrains.kotlin.plugin.compose") version "2.4.20" apply false
  id("org.jetbrains.kotlin.plugin.serialization") version "2.4.20" apply false
}
