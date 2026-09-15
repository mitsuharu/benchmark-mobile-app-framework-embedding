import XCTest

@testable import HostApp

/// Covers the conversion from the method calls the Dart side makes to typed
/// events — the part of the embedding that is easy to get wrong and hard to
/// see fail. No engine is started: calls are fed to `receive` directly.
final class RepoSearchBridgeTests: XCTestCase {
  private var runtime: FlutterRepoSearch!

  override func setUp() {
    super.setUp()
    runtime = FlutterRepoSearch()
  }

  private func events(for method: String, _ arguments: Any?) -> [RepoSearchEvent] {
    var events: [RepoSearchEvent] = []
    let bridge = RepoSearchBridge(runtime: runtime) { events.append($0) }
    bridge.start()
    runtime.receive(method: method, arguments: arguments)
    return events
  }

  private func repository(
    id: Any = NSNumber(value: 65_750_241),
    fullName: Any = "expo/expo",
    stars: Any = NSNumber(value: 51_842),
    language: Any = "TypeScript"
  ) -> [String: Any] {
    ["id": id, "fullName": fullName, "stars": stars, "language": language]
  }

  func testDecodesRepositories() throws {
    let events = events(
      for: "searchSucceeded",
      ["keyword": "expo", "repositories": [repository()]]
    )

    guard case .succeeded(let keyword, let repositories) = try XCTUnwrap(events.first) else {
      return XCTFail("expected .succeeded, got \(events)")
    }
    XCTAssertEqual(keyword, "expo")
    XCTAssertEqual(
      repositories,
      [SearchedRepository(id: 65_750_241, fullName: "expo/expo", stars: 51_842, language: "TypeScript")]
    )
  }

  func testTreatsDartNullAsMissing() throws {
    let events = events(
      for: "searchSucceeded",
      ["keyword": "expo", "repositories": [repository(language: NSNull())]]
    )

    guard case .succeeded(_, let repositories) = try XCTUnwrap(events.first) else {
      return XCTFail("expected .succeeded, got \(events)")
    }
    XCTAssertNil(repositories[0].language)
  }

  func testSkipsRepositoriesMissingRequiredFields() throws {
    var withoutName = repository()
    withoutName.removeValue(forKey: "fullName")
    let events = events(
      for: "searchSucceeded",
      ["keyword": "expo", "repositories": [repository(), withoutName, "junk"]]
    )

    guard case .succeeded(_, let repositories) = try XCTUnwrap(events.first) else {
      return XCTFail("expected .succeeded, got \(events)")
    }
    XCTAssertEqual(repositories.count, 1)
  }

  func testDecodesFailure() throws {
    let events = events(
      for: "searchFailed",
      ["keyword": "expo", "message": "API rate limit exceeded"]
    )

    guard case .failed(let keyword, let message) = try XCTUnwrap(events.first) else {
      return XCTFail("expected .failed, got \(events)")
    }
    XCTAssertEqual(keyword, "expo")
    XCTAssertEqual(message, "API rate limit exceeded")
  }

  func testIgnoresOtherCalls() {
    XCTAssertTrue(events(for: "somethingElse", ["keyword": "expo"]).isEmpty)
    XCTAssertTrue(events(for: "searchSucceeded", nil).isEmpty)
    XCTAssertTrue(events(for: "mark", ["name": "searchTapped", "epochMs": 1]).isEmpty)
  }

  func testCloseAsksTheHostToGoBack() {
    var closed = false
    runtime.onClose = { closed = true }

    runtime.receive(method: "close", arguments: nil)

    XCTAssertTrue(closed)
  }

  func testNotifiesDelegateAndClosure() {
    final class SpyDelegate: RepoSearchBridgeDelegate {
      var events: [RepoSearchEvent] = []
      func repoSearchBridge(_ bridge: RepoSearchBridge, didReceive event: RepoSearchEvent) {
        events.append(event)
      }
    }

    let delegate = SpyDelegate()
    var closureEvents: [RepoSearchEvent] = []
    let bridge = RepoSearchBridge(runtime: runtime, delegate: delegate) { closureEvents.append($0) }
    bridge.start()

    runtime.receive(method: "searchFailed", arguments: ["keyword": "expo", "message": "boom"])

    XCTAssertEqual(delegate.events.count, 1)
    XCTAssertEqual(closureEvents.count, 1)
  }

  func testStartAndStopAreIdempotent() {
    var events: [RepoSearchEvent] = []
    let bridge = RepoSearchBridge(runtime: runtime) { events.append($0) }
    bridge.stop()
    bridge.start()
    bridge.start()

    runtime.receive(method: "searchFailed", arguments: ["keyword": "expo", "message": "boom"])
    XCTAssertEqual(events.count, 1, "a second start must not register a second listener")

    bridge.stop()
    runtime.receive(method: "searchFailed", arguments: ["keyword": "expo", "message": "boom"])
    XCTAssertEqual(events.count, 1)
  }

  func testSendingBeforeTheEngineStartsIsHarmless() {
    RepoSearchBridge(runtime: runtime).send(.setKeyword("swift"))
  }
}
