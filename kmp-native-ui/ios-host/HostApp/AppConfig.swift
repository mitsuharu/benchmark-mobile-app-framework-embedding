import Foundation

/// Build-time settings, read from Info.plist.
enum AppConfig {
  static let defaultAPIBaseURL = URL(string: "https://api.github.com")!

  /// Where the search screen sends its requests. The benchmark build points
  /// this at bench/mock-server through the `BENCH_API_BASE_URL` build setting;
  /// every other build talks to GitHub.
  static var apiBaseURL: URL {
    apiBaseURL(from: Bundle.main.object(forInfoDictionaryKey: "BenchAPIBaseURL") as? String)
  }

  static func apiBaseURL(from value: String?) -> URL {
    guard let value, !value.isEmpty, let url = URL(string: value) else {
      return defaultAPIBaseURL
    }
    return url
  }
}
