import SwiftUI

@main
struct HostApp: App {
  init() {
    // Starts the Flutter engine once, before the screen is first opened —
    // Flutter's recommended setup for adding it to an existing app.
    FlutterRepoSearch.shared.start()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
