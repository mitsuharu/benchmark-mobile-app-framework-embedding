package com.example.sample.expo.brownfield.host

import android.app.Application
import com.example.sample.expo.brownfield.reposearchkit.BenchMarkerRelay
import com.example.sample.expo.brownfield.reposearchkit.ReactNativeHostManager

class HostApplication : Application() {
  override fun onCreate() {
    super.onCreate()
    // Boots React Native at launch, as the iOS host does in `HostApp.init`, so
    // the first visit to the screen does not pay for it. The benchmark
    // compares every implementation with its runtime started up front.
    ReactNativeHostManager.shared.initialize(this)
    // Writes the markers the React Native screen reports to logcat.
    BenchMarkerRelay.start()
  }
}
