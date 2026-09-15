import XCTest

@testable import RepoSearchKit

/// Covers the channel between the host app and the search screen.
final class RepoSearchBridgeTests: XCTestCase {
  private var channel: RepoSearchChannel!

  override func setUp() {
    super.setUp()
    channel = RepoSearchChannel()
  }

  private let repository = SearchedRepository(
    id: 65_750_241,
    fullName: "expo/expo",
    stars: 51_842,
    language: "TypeScript"
  )

  func testNotifiesDelegateAndClosure() {
    final class SpyDelegate: RepoSearchBridgeDelegate {
      var events: [RepoSearchEvent] = []
      func repoSearchBridge(_ bridge: RepoSearchBridge, didReceive event: RepoSearchEvent) {
        events.append(event)
      }
    }

    let delegate = SpyDelegate()
    var closureEvents: [RepoSearchEvent] = []
    let bridge = RepoSearchBridge(channel: channel, delegate: delegate) { closureEvents.append($0) }
    bridge.start()

    channel.post(.succeeded(keyword: "expo", repositories: [repository]))

    XCTAssertEqual(delegate.events.count, 1)
    XCTAssertEqual(closureEvents.count, 1)
    guard case .succeeded(let keyword, let repositories) = delegate.events[0] else {
      return XCTFail("expected .succeeded, got \(delegate.events[0])")
    }
    XCTAssertEqual(keyword, "expo")
    XCTAssertEqual(repositories, [repository])
  }

  func testDeliversNothingBeforeStart() {
    var events: [RepoSearchEvent] = []
    _ = RepoSearchBridge(channel: channel) { events.append($0) }

    channel.post(.failed(keyword: "expo", message: "boom"))

    XCTAssertTrue(events.isEmpty)
  }

  func testDeliversNothingAfterStop() {
    var events: [RepoSearchEvent] = []
    let bridge = RepoSearchBridge(channel: channel) { events.append($0) }
    bridge.start()
    bridge.stop()

    channel.post(.failed(keyword: "expo", message: "boom"))

    XCTAssertTrue(events.isEmpty)
  }

  func testStartAndStopAreIdempotent() {
    var events: [RepoSearchEvent] = []
    let bridge = RepoSearchBridge(channel: channel) { events.append($0) }
    bridge.stop()
    bridge.start()
    bridge.start()

    channel.post(.failed(keyword: "expo", message: "boom"))

    XCTAssertEqual(events.count, 1, "a second start must not register a second listener")
    bridge.stop()
    bridge.stop()
  }

  func testReleasingTheBridgeStopsListening() {
    var events: [RepoSearchEvent] = []
    var bridge: RepoSearchBridge? = RepoSearchBridge(channel: channel) { events.append($0) }
    bridge?.start()
    bridge = nil

    channel.post(.failed(keyword: "expo", message: "boom"))

    XCTAssertTrue(events.isEmpty)
  }

  func testSendsCommandsToTheScreen() {
    var commands: [RepoSearchCommand] = []
    _ = channel.addCommandListener { commands.append($0) }

    RepoSearchBridge(channel: channel).send(.setKeyword("swift"))

    XCTAssertEqual(commands, [.setKeyword("swift")])
  }

  func testSendingWithNoScreenOpenIsHarmless() {
    RepoSearchBridge(channel: channel).send(.setKeyword("swift"))
  }
}
