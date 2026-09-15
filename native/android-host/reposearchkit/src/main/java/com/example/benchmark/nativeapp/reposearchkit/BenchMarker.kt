package com.example.benchmark.nativeapp.reposearchkit

import android.util.Log

/**
 * The search screen's copy of the host app's `BenchMarker`: the embedded side
 * of every implementation reports its own markers (see AGENTS.md).
 */
internal object BenchMarker {
  fun mark(name: String, epochMs: Long = System.currentTimeMillis()) {
    Log.i("Bench", "BENCH|$name|$epochMs")
  }
}
