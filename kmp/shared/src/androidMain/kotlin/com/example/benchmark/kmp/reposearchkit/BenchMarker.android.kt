package com.example.benchmark.kmp.reposearchkit

import android.util.Log

internal actual fun epochMillis(): Long = System.currentTimeMillis()

internal actual fun writeMarker(line: String) {
  Log.i("Bench", line)
}
