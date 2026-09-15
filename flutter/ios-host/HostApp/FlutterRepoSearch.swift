import Flutter
import Foundation

/// One repository as it arrives from the Flutter screen.
struct SearchedRepository: Identifiable, Hashable {
  let id: Int
  let fullName: String
  let stars: Int
  let language: String?

  init(id: Int, fullName: String, stars: Int, language: String?) {
    self.id = id
    self.fullName = fullName
    self.stars = stars
    self.language = language
  }

  init?(json: Any) {
    guard let json = json as? [String: Any],
      let id = (json["id"] as? NSNumber)?.intValue,
      let fullName = json["fullName"] as? String
    else {
      return nil
    }
    self.init(
      id: id,
      fullName: fullName,
      stars: (json["stars"] as? NSNumber)?.intValue ?? 0,
      // Dart's null arrives as NSNull.
      language: json["language"] as? String
    )
  }
}

/// What the Flutter screen reports back. Mirrors `lib/src/host_channel.dart`.
enum RepoSearchEvent {
  case succeeded(keyword: String, repositories: [SearchedRepository])
  case failed(keyword: String, message: String)

  /// Decodes one method call from the Flutter screen, or nil when it is not a
  /// search result.
  init?(method: String, arguments: Any?) {
    guard let arguments = arguments as? [String: Any],
      let keyword = arguments["keyword"] as? String
    else {
      return nil
    }
    switch method {
    case "searchSucceeded":
      let raw = arguments["repositories"] as? [Any] ?? []
      self = .succeeded(keyword: keyword, repositories: raw.compactMap(SearchedRepository.init))
    case "searchFailed":
      self = .failed(keyword: keyword, message: arguments["message"] as? String ?? "unknown error")
    default:
      return nil
    }
  }
}

/// What the host app asks the Flutter screen to do. The mirror image of
/// `RepoSearchEvent`.
enum RepoSearchCommand: Equatable {
  /// Replaces the keyword on a screen that is already open.
  case setKeyword(String)
}

protocol RepoSearchBridgeDelegate: AnyObject {
  func repoSearchBridge(_ bridge: RepoSearchBridge, didReceive event: RepoSearchEvent)
}

/// The host app's end of the channel, delivering events through either a
/// delegate or a closure — the same shape as the bridge the other
/// implementations ship. Flutter ships no native code of its own here, so the
/// typed bridge lives in the host app.
final class RepoSearchBridge {
  weak var delegate: RepoSearchBridgeDelegate?
  var onEvent: ((RepoSearchEvent) -> Void)?

  private let runtime: FlutterRepoSearch
  private var listenerID: UUID?

  init(
    runtime: FlutterRepoSearch = .shared,
    delegate: RepoSearchBridgeDelegate? = nil,
    onEvent: ((RepoSearchEvent) -> Void)? = nil
  ) {
    self.runtime = runtime
    self.delegate = delegate
    self.onEvent = onEvent
  }

  deinit {
    stop()
  }

  func start() {
    guard listenerID == nil else { return }
    listenerID = runtime.addEventListener { [weak self] event in
      guard let self else { return }
      self.delegate?.repoSearchBridge(self, didReceive: event)
      self.onEvent?(event)
    }
  }

  func stop() {
    guard let listenerID else { return }
    runtime.removeEventListener(listenerID)
    self.listenerID = nil
  }

  /// Sends a command to the Flutter screen.
  func send(_ command: RepoSearchCommand) {
    runtime.send(command)
  }
}

/// The Flutter engine behind the screen, started once at launch and reused by
/// every visit, plus the method channel to the Dart side.
///
/// The engine keeps one Dart app alive across visits, so opening the screen
/// sends `start` to give it a fresh screen for the keyword — what React Native
/// gets from creating a new root view with new `initialProps`.
final class FlutterRepoSearch {
  static let shared = FlutterRepoSearch()

  static let channelName = "repo_search"

  let engine = FlutterEngine(name: "repo_search")

  /// Called when the Flutter screen asks to go back to the host.
  var onClose: (() -> Void)?

  private var channel: FlutterMethodChannel?
  private var eventListeners: [UUID: (RepoSearchEvent) -> Void] = [:]

  func start() {
    guard channel == nil else { return }
    // The module uses no plugins, so there is nothing to register.
    engine.run()
    // On iOS, Flutter builds its accessibility tree only once an assistive
    // technology asks for it, so UI automation (XCTest, agent-device) sees an
    // empty view. React Native and Compose always expose theirs; turning it on
    // here keeps the screen operable and the work comparable. Every later
    // visit turns it on again (see `SemanticsFlutterViewController`).
    engine.ensureSemanticsEnabled()

    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.receive(method: call.method, arguments: call.arguments)
      result(nil)
    }
    self.channel = channel
  }

  /// Resets the screen for a new visit. Call before showing the view controller.
  func prepareScreen(keyword: String, apiBaseURL: URL) {
    channel?.invokeMethod(
      "start",
      arguments: ["keyword": keyword, "apiBaseUrl": apiBaseURL.absoluteString]
    )
  }

  func send(_ command: RepoSearchCommand) {
    switch command {
    case .setKeyword(let keyword):
      channel?.invokeMethod("setKeyword", arguments: ["keyword": keyword])
    }
  }

  func addEventListener(_ listener: @escaping (RepoSearchEvent) -> Void) -> UUID {
    let id = UUID()
    eventListeners[id] = listener
    return id
  }

  func removeEventListener(_ id: UUID) {
    eventListeners[id] = nil
  }

  /// Handles one call from the Dart side. Flutter delivers them on the main
  /// thread. Internal so the decoding can be tested without an engine.
  func receive(method: String, arguments: Any?) {
    switch method {
    case "mark":
      // The Dart side takes the time; the host writes the line (AGENTS.md).
      guard let arguments = arguments as? [String: Any],
        let name = arguments["name"] as? String,
        let epochMs = (arguments["epochMs"] as? NSNumber)?.doubleValue
      else {
        return
      }
      BenchMarker.mark(name, at: Date(timeIntervalSince1970: epochMs / 1000))
    case "close":
      onClose?()
    default:
      guard let event = RepoSearchEvent(method: method, arguments: arguments) else { return }
      for listener in eventListeners.values {
        listener(event)
      }
    }
  }
}
