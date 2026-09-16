import RepoSearchKit
import XCTest

@testable import HostApp

/// Covers the host app's own side of the embedding: what it does with the
/// events the Kotlin framework hands it.
final class SearchResultsStoreTests: XCTestCase {
  private var store: SearchResultsStore!

  override func setUp() {
    super.setUp()
    store = SearchResultsStore()
  }

  private let repository = SearchedRepository(
    id: 1,
    fullName: "expo/expo",
    stars: 51_842,
    language: "TypeScript"
  )

  private func succeeded(_ repositories: [SearchedRepository]) -> RepoSearchEvent {
    RepoSearchEventSucceeded(keyword: "expo", repositories: repositories)
  }

  func testStartsEmpty() {
    XCTAssertNil(store.lastKeyword)
    XCTAssertNil(store.errorMessage)
    XCTAssertTrue(store.repositories.isEmpty)
  }

  func testKeepsResultsFromASuccessfulSearch() {
    store.onRepoSearchEvent(event: succeeded([repository]))

    XCTAssertEqual(store.lastKeyword, "expo")
    XCTAssertEqual(store.repositories, [repository])
    XCTAssertEqual(store.repositories[0].stars, 51_842)
    XCTAssertNil(store.errorMessage)
  }

  func testKeepsAMissingLanguageAsNil() {
    let noLanguage = SearchedRepository(id: 2, fullName: "a/b", stars: 0, language: nil)

    store.onRepoSearchEvent(event: succeeded([noLanguage]))

    XCTAssertNil(store.repositories[0].language)
  }

  func testAFailureClearsPreviousResults() {
    store.onRepoSearchEvent(event: succeeded([repository]))

    store.onRepoSearchEvent(
      event: RepoSearchEventFailed(keyword: "expo", message: "API rate limit exceeded"))

    XCTAssertEqual(store.errorMessage, "API rate limit exceeded")
    XCTAssertTrue(store.repositories.isEmpty)
    XCTAssertEqual(store.lastKeyword, "expo")
  }

  func testASuccessClearsAPreviousFailure() {
    store.onRepoSearchEvent(event: RepoSearchEventFailed(keyword: "expo", message: "boom"))

    store.onRepoSearchEvent(event: succeeded([repository]))

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
    store.keyword = "  compose-multiplatform \n"
    XCTAssertEqual(store.effectiveKeyword, "compose-multiplatform")
  }
}

/// The Kotlin API as Swift sees it through the Objective-C interop.
final class RepoSearchBridgeInteropTests: XCTestCase {
  func testStartAndStopAreIdempotent() {
    let bridge = RepoSearchBridge(listener: nil, onEvent: nil)
    bridge.stop()
    bridge.start()
    bridge.start()
    bridge.stop()
    bridge.stop()
  }

  func testSendingWithNoScreenOpenIsHarmless() {
    RepoSearchBridge(listener: nil, onEvent: nil)
      .send(command: RepoSearchCommandSetKeyword(keyword: "swift"))
  }

}

/// The screen's view model: the shared Kotlin model as SwiftUI sees it.
final class RepoSearchViewModelTests: XCTestCase {
  private func makeModel() -> RepoSearchViewModel {
    RepoSearchViewModel(keyword: "expo", apiBaseURL: URL(string: "http://127.0.0.1:8787")!)
  }

  func testStartsWithTheKeywordTheHostPassedIn() {
    let model = makeModel()
    defer { model.dispose() }

    XCTAssertEqual(model.keyword, "expo")
    XCTAssertTrue(model.repositories.isEmpty)
    XCTAssertFalse(model.isLoading)
    XCTAssertNil(model.errorMessage)
  }

  func testFollowsAKeywordTheHostSendsWhileOpen() {
    let model = makeModel()
    defer { model.dispose() }

    RepoSearchBridge(listener: nil, onEvent: nil)
      .send(command: RepoSearchCommandSetKeyword(keyword: "swift"))

    XCTAssertEqual(model.keyword, "swift")
  }

  func testStopsFollowingCommandsOnceDisposed() {
    let model = makeModel()
    model.dispose()

    RepoSearchBridge(listener: nil, onEvent: nil)
      .send(command: RepoSearchCommandSetKeyword(keyword: "swift"))

    XCTAssertEqual(model.keyword, "expo")
  }
}
