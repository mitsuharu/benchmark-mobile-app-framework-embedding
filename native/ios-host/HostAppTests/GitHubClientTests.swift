import RepoSearchKit
import XCTest

final class GitHubClientTests: XCTestCase {
  private func client(
    baseURL: URL = GitHubClient.defaultBaseURL,
    _ response: StubURLProtocol.Response = .init(body: Fixture.searchResponse)
  ) -> GitHubClient {
    GitHubClient(baseURL: baseURL, session: StubURLProtocol.session { _ in response })
  }

  func testQueriesTheKeywordSortedByStars() async throws {
    _ = try await client().searchRepositories(keyword: "expo")

    let request = try XCTUnwrap(StubURLProtocol.requests.first)
    let url = try XCTUnwrap(request.url)
    let query = Dictionary(
      uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        ?? [])
        .map { ($0.name, $0.value) }
    )
    XCTAssertEqual(url.path, "/search/repositories")
    XCTAssertEqual(query["q"], "expo")
    XCTAssertEqual(query["sort"], "stars")
    XCTAssertEqual(query["order"], "desc")
    XCTAssertEqual(query["per_page"], "20")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
  }

  func testSendsRequestsToTheConfiguredBaseURL() async throws {
    // The benchmark build points the client at bench/mock-server.
    let mock = URL(string: "http://127.0.0.1:8787")!

    _ = try await client(baseURL: mock).searchRepositories(keyword: "expo")

    let url = try XCTUnwrap(StubURLProtocol.requests.first?.url)
    XCTAssertEqual(url.host, "127.0.0.1")
    XCTAssertEqual(url.port, 8787)
    XCTAssertEqual(url.path, "/search/repositories")
  }

  func testMapsTheResponseOntoRepositories() async throws {
    let repositories = try await client().searchRepositories(keyword: "expo")

    XCTAssertEqual(repositories.count, 2)
    XCTAssertEqual(repositories[0].id, 65_750_241)
    XCTAssertEqual(repositories[0].fullName, "expo/expo")
    XCTAssertEqual(repositories[0].description, "An open-source framework")
    XCTAssertEqual(repositories[0].stars, 51_842)
    XCTAssertEqual(repositories[0].language, "TypeScript")
    XCTAssertEqual(repositories[0].htmlURL, URL(string: "https://github.com/expo/expo"))
  }

  func testKeepsNullDescriptionAndLanguageAsNil() async throws {
    let repositories = try await client().searchRepositories(keyword: "expo")

    XCTAssertNil(repositories[1].description)
    XCTAssertNil(repositories[1].language)
  }

  func testSurfacesTheAPIMessageWhenTheRequestIsRejected() async {
    // Unauthenticated search is rate limited to 10 requests / minute.
    let rejected = client(.init(status: 403, body: #"{"message":"API rate limit exceeded"}"#))

    do {
      _ = try await rejected.searchRepositories(keyword: "expo")
      XCTFail("expected an error")
    } catch {
      XCTAssertEqual(error.localizedDescription, "API rate limit exceeded")
    }
  }

  func testFallsBackToTheStatusCodeWhenThereIsNoMessage() async {
    let failing = client(.init(status: 500, body: "{}"))

    do {
      _ = try await failing.searchRepositories(keyword: "expo")
      XCTFail("expected an error")
    } catch {
      XCTAssertEqual(error.localizedDescription, "GitHub API responded with 500")
    }
  }
}
