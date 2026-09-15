import XCTest

@testable import HostApp

final class AppConfigTests: XCTestCase {
  func testUsesGitHubWhenTheBuildSettingIsUnset() {
    XCTAssertEqual(AppConfig.apiBaseURL(from: nil), AppConfig.defaultAPIBaseURL)
    // An unset build setting expands to an empty string in Info.plist.
    XCTAssertEqual(AppConfig.apiBaseURL(from: ""), AppConfig.defaultAPIBaseURL)
  }

  func testUsesTheConfiguredBaseURL() {
    XCTAssertEqual(
      AppConfig.apiBaseURL(from: "http://127.0.0.1:8787"),
      URL(string: "http://127.0.0.1:8787")
    )
  }

  func testTheDefaultIsTheRealAPI() {
    XCTAssertEqual(AppConfig.defaultAPIBaseURL.absoluteString, "https://api.github.com")
  }
}

final class BenchMarkerTests: XCTestCase {
  func testTheProcessStartIsInThePast() throws {
    let start = try XCTUnwrap(BenchMarker.processStartDate())

    XCTAssertLessThan(start, Date())
    // The test runner launched this process moments ago, not hours.
    XCTAssertGreaterThan(start, Date().addingTimeInterval(-3600))
  }
}
