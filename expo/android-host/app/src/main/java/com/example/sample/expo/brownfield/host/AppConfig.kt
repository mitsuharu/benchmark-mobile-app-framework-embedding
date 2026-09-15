package com.example.sample.expo.brownfield.host

/** Build-time settings. */
object AppConfig {
  const val DEFAULT_API_BASE_URL = "https://api.github.com"

  /**
   * Where the search screen sends its requests. The benchmark build points
   * this at bench/mock-server through `-PbenchApiBaseUrl`; every other build
   * talks to GitHub.
   */
  val apiBaseUrl: String
    get() = apiBaseUrl(BuildConfig.BENCH_API_BASE_URL)

  fun apiBaseUrl(configured: String): String = configured.ifEmpty { DEFAULT_API_BASE_URL }
}
