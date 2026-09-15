package com.example.benchmark.flutter.host

import android.os.Process
import android.os.SystemClock
import android.util.Log

/**
 * Emits the benchmark markers described in AGENTS.md.
 *
 * The benchmark runner reads these lines from logcat, so the format is part of
 * the contract: `BENCH|<name>|<epochMs>`.
 */
object BenchMarker {
  private const val TAG = "Bench"
  private var didMarkLaunch = false

  fun mark(name: String, epochMs: Long = System.currentTimeMillis()) {
    Log.i(TAG, "BENCH|$name|$epochMs")
  }

  /**
   * Marks the first frame of the host screen, together with the moment the
   * process started. Only the first call per process counts, so a recreated
   * activity is not mistaken for a launch.
   */
  fun markLaunch() {
    if (didMarkLaunch) return
    didMarkLaunch = true
    mark("processStart", processStartEpochMs())
    mark("hostFirstFrame")
  }

  /** When this process started, converted from uptime to wall-clock time. */
  fun processStartEpochMs(): Long =
    System.currentTimeMillis() - (SystemClock.uptimeMillis() - Process.getStartUptimeMillis())
}
