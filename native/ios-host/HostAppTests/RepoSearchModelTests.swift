import XCTest

@testable import RepoSearchKit

/// Covers the search screen's behaviour without rendering it.
@MainActor
final class RepoSearchModelTests: XCTestCase {
  private var channel: RepoSearchChannel!
  private var events: [RepoSearchEvent] = []

  override func setUp() {
    super.setUp()
    channel = RepoSearchChannel()
    events = []
    _ = channel.addEventListener { [unowned self] in events.append($0) }
  }

  private func model(_ response: StubURLProtocol.Response = .init(body: Fixture.searchResponse))
    -> RepoSearchModel
  {
    let session = StubURLProtocol.session { _ in response }
    return RepoSearchModel(
      keyword: "expo",
      client: GitHubClient(session: session),
      channel: channel
    )
  }

  func testStartsWithTheKeywordFromTheHostAndNoResults() {
    let model = model()

    XCTAssertEqual(model.keyword, "expo")
    XCTAssertTrue(model.repositories.isEmpty)
    XCTAssertFalse(model.isLoading)
  }

  func testListsAndReportsTheResults() async {
    let model = model()

    await model.search()

    XCTAssertEqual(model.repositories.map(\.fullName), ["expo/expo", "a/b"])
    XCTAssertFalse(model.isLoading)
    XCTAssertEqual(events.count, 1)
    guard case .succeeded(let keyword, let repositories) = events.first else {
      return XCTFail("expected .succeeded, got \(events)")
    }
    XCTAssertEqual(keyword, "expo")
    XCTAssertEqual(
      repositories,
      [
        SearchedRepository(
          id: 65_750_241, fullName: "expo/expo", stars: 51_842, language: "TypeScript"),
        SearchedRepository(id: 1, fullName: "a/b", stars: 0, language: nil),
      ]
    )
  }

  func testShowsAndReportsAFailure() async {
    let model = model(.init(status: 403, body: #"{"message":"API rate limit exceeded"}"#))

    await model.search()

    XCTAssertEqual(model.errorMessage, "API rate limit exceeded")
    XCTAssertTrue(model.repositories.isEmpty)
    guard case .failed(let keyword, let message) = events.first else {
      return XCTFail("expected .failed, got \(events)")
    }
    XCTAssertEqual(keyword, "expo")
    XCTAssertEqual(message, "API rate limit exceeded")
  }

  func testFollowsAKeywordTheHostSendsWhileOpen() async {
    let model = model()

    channel.send(.setKeyword("swift"))
    await model.search()

    XCTAssertEqual(model.keyword, "swift")
    let query = StubURLProtocol.requests.first?.url?.query ?? ""
    XCTAssertTrue(query.contains("q=swift"), query)
  }

  func testClearsThePreviousResultsWhenTheKeywordIsReplaced() async {
    let model = model()
    await model.search()

    channel.send(.setKeyword("swift"))

    XCTAssertTrue(model.repositories.isEmpty)
  }
}
