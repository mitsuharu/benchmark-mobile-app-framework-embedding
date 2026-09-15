package com.example.benchmark.flutter.host

import android.app.Application

class HostApplication : Application() {
  override fun onCreate() {
    super.onCreate()
    // Starts the Flutter engine once, before the screen is first opened —
    // Flutter's recommended setup for adding it to an existing app.
    FlutterRepoSearch.shared.start(this)
  }
}
