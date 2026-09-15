import Foundation

/// One repository as the search screen reports it to the host.
public struct SearchedRepository: Identifiable, Hashable, Sendable {
  public let id: Int
  public let fullName: String
  public let stars: Int
  public let language: String?

  public init(id: Int, fullName: String, stars: Int, language: String?) {
    self.id = id
    self.fullName = fullName
    self.stars = stars
    self.language = language
  }

  init(_ repository: Repository) {
    self.init(
      id: repository.id,
      fullName: repository.fullName,
      stars: repository.stars,
      language: repository.language
    )
  }
}

/// What the search screen reports back.
public enum RepoSearchEvent {
  case succeeded(keyword: String, repositories: [SearchedRepository])
  case failed(keyword: String, message: String)
}

/// What the host app asks the search screen to do. The mirror image of
/// `RepoSearchEvent`.
public enum RepoSearchCommand: Equatable {
  /// Replaces the keyword on a screen that is already open. The keyword given
  /// to `RepoSearchView` only reaches the screen while it is being created.
  case setKeyword(String)
}

public protocol RepoSearchBridgeDelegate: AnyObject {
  func repoSearchBridge(_ bridge: RepoSearchBridge, didReceive event: RepoSearchEvent)
}

/// The host app's end of the channel, delivering events through either a
/// delegate or a closure.
///
/// It has the same shape as the bridge the other implementations ship with
/// their embedded screen, so the host apps read the same. Here both ends are
/// Swift in one process, so values travel as they are: there is no wire format
/// to encode, which is the baseline the other channels are measured against.
///
/// Main thread only, like the UI on both ends.
public final class RepoSearchBridge {
  public weak var delegate: RepoSearchBridgeDelegate?
  public var onEvent: ((RepoSearchEvent) -> Void)?

  private let channel: RepoSearchChannel
  private var listenerID: UUID?

  public convenience init(
    delegate: RepoSearchBridgeDelegate? = nil,
    onEvent: ((RepoSearchEvent) -> Void)? = nil
  ) {
    self.init(channel: .shared, delegate: delegate, onEvent: onEvent)
  }

  init(
    channel: RepoSearchChannel,
    delegate: RepoSearchBridgeDelegate? = nil,
    onEvent: ((RepoSearchEvent) -> Void)? = nil
  ) {
    self.channel = channel
    self.delegate = delegate
    self.onEvent = onEvent
  }

  deinit {
    stop()
  }

  public func start() {
    guard listenerID == nil else { return }
    listenerID = channel.addEventListener { [weak self] event in
      guard let self else { return }
      self.delegate?.repoSearchBridge(self, didReceive: event)
      self.onEvent?(event)
    }
  }

  public func stop() {
    guard let listenerID else { return }
    channel.removeEventListener(listenerID)
    self.listenerID = nil
  }

  /// Sends a command to the search screen. It is dropped when no screen is open.
  public func send(_ command: RepoSearchCommand) {
    channel.send(command)
  }
}

/// The in-process message bus between the host app and the search screen.
final class RepoSearchChannel {
  static let shared = RepoSearchChannel()

  private var eventListeners: [UUID: (RepoSearchEvent) -> Void] = [:]
  private var commandListeners: [UUID: (RepoSearchCommand) -> Void] = [:]

  func addEventListener(_ listener: @escaping (RepoSearchEvent) -> Void) -> UUID {
    let id = UUID()
    eventListeners[id] = listener
    return id
  }

  func removeEventListener(_ id: UUID) {
    eventListeners[id] = nil
  }

  func post(_ event: RepoSearchEvent) {
    for listener in eventListeners.values {
      listener(event)
    }
  }

  func addCommandListener(_ listener: @escaping (RepoSearchCommand) -> Void) -> UUID {
    let id = UUID()
    commandListeners[id] = listener
    return id
  }

  func removeCommandListener(_ id: UUID) {
    commandListeners[id] = nil
  }

  func send(_ command: RepoSearchCommand) {
    for listener in commandListeners.values {
      listener(command)
    }
  }
}
