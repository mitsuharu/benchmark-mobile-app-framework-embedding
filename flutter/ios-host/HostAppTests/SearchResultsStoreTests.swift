import XCTest

@testable import HostApp

/// Covers the host app's own side of the embedding: what it does with the
/// events the Flutter screen hands it.
final class SearchResultsStoreTests: XCTestCase {
  private var store: SearchResultsStore!

  override func setUp() {
    super.setUp()
    store = SearchResultsStore()
  }

  private func send(_ event: RepoSearchEvent) {
    store.repoSearchBridge(RepoSearchBridge(runtime: FlutterRepoSearch()), didReceive: event)
  }

  private let repository = SearchedRepository(
    id: 1,
    fullName: "expo/expo",
    stars: 51_842,
    language: "TypeScript"
  )

  func testStartsEmpty() {
    XCTAssertNil(store.lastKeyword)
    XCTAssertNil(store.errorMessage)
    XCTAssertTrue(store.repositories.isEmpty)
  }

  func testKeepsResultsFromASuccessfulSearch() {
    send(.succeeded(keyword: "expo", repositories: [repository]))

    XCTAssertEqual(store.lastKeyword, "expo")
    XCTAssertEqual(store.repositories, [repository])
    XCTAssertNil(store.errorMessage)
  }

  func testAFailureClearsPreviousResults() {
    send(.succeeded(keyword: "expo", repositories: [repository]))

    send(.failed(keyword: "expo", message: "API rate limit exceeded"))

    XCTAssertEqual(store.errorMessage, "API rate limit exceeded")
    XCTAssertTrue(store.repositories.isEmpty)
    XCTAssertEqual(store.lastKeyword, "expo")
  }

  func testASuccessClearsAPreviousFailure() {
    send(.failed(keyword: "expo", message: "boom"))

    send(.succeeded(keyword: "expo", repositories: [repository]))

    XCTAssertNil(store.errorMessage)
    XCTAssertEqual(store.repositories.count, 1)
  }

  func testEffectiveKeywordFallsBackWhenBlank() {
    store.keyword = "   "
    XCTAssertEqual(store.effectiveKeyword, "expo")

    store.keyword = ""
    XCTAssertEqual(store.effectiveKeyword, "expo")
  }

  func testEffectiveKeywordIsTrimmed() {
    store.keyword = "  flutter \n"
    XCTAssertEqual(store.effectiveKeyword, "flutter")
  }
}
