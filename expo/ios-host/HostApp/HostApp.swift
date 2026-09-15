import RepoSearchKit
import SwiftUI

@main
struct HostApp: App {
  init() {
    // Boots the React Native runtime once, before any React Native view is created.
    ReactNativeHostManager.shared.initialize()
    // Writes the markers the React Native screen reports to the app log.
    BenchMarkerRelay.start()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
