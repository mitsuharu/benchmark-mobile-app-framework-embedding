import Foundation

/// One repository from the GitHub Search API.
public struct Repository: Identifiable, Hashable, Sendable {
  public let id: Int
  public let fullName: String
  public let description: String?
  public let stars: Int
  public let language: String?
  public let htmlURL: URL?
}

public struct GitHubError: LocalizedError, Equatable {
  public let message: String

  public var errorDescription: String? { message }
}

/// Minimal GitHub Search API client.
/// https://docs.github.com/en/rest/search/search#search-repositories
public struct GitHubClient: Sendable {
  public static let defaultBaseURL = URL(string: "https://api.github.com")!

  private let baseURL: URL
  private let session: URLSession

  public init(baseURL: URL = GitHubClient.defaultBaseURL, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
  }

  public func searchRepositories(keyword: String, perPage: Int = 20) async throws -> [Repository] {
    var components = URLComponents(
      url: baseURL.appendingPathComponent("search/repositories"),
      resolvingAgainstBaseURL: false
    )!
    components.queryItems = [
      URLQueryItem(name: "q", value: keyword),
      URLQueryItem(name: "sort", value: "stars"),
      URLQueryItem(name: "order", value: "desc"),
      URLQueryItem(name: "per_page", value: String(perPage)),
    ]

    var request = URLRequest(url: components.url!)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

    let (data, response) = try await session.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0

    guard (200..<300).contains(status) else {
      // Unauthenticated search is rate limited to 10 requests / minute.
      let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.message
      throw GitHubError(message: message ?? "GitHub API responded with \(status)")
    }

    return try JSONDecoder().decode(SearchResponse.self, from: data).items.map { item in
      Repository(
        id: item.id,
        fullName: item.fullName,
        description: item.description,
        stars: item.stargazersCount,
        language: item.language,
        htmlURL: URL(string: item.htmlURL)
      )
    }
  }
}

private struct SearchResponse: Decodable {
  struct Item: Decodable {
    let id: Int
    let fullName: String
    let description: String?
    let stargazersCount: Int
    let language: String?
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
      case id
      case fullName = "full_name"
      case description
      case stargazersCount = "stargazers_count"
      case language
      case htmlURL = "html_url"
    }
  }

  let items: [Item]
}

private struct ErrorResponse: Decodable {
  let message: String?
}
