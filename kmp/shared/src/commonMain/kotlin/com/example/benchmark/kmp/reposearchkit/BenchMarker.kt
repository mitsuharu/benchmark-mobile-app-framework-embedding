package com.example.benchmark.kmp.reposearchkit

/**
 * The search screen's markers (see AGENTS.md). Kotlin writes them itself, to
 * logcat on Android and to unified logging on iOS, so they need no trip to
 * the host app.
 */
internal object BenchMarker {
  fun mark(name: String) {
    writeMarker("BENCH|$name|${epochMillis()}")
  }
}

/** Wall-clock time, comparable with the host app's markers. */
internal expect fun epochMillis(): Long

internal expect fun writeMarker(line: String)
