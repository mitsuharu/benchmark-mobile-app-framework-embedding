import RepoSearchKit
import XCTest

/// Covers the line the relay writes for a marker the React Native screen sends.
final class BenchMarkerRelayTests: XCTestCase {
  func testFormatsAMarker() {
    // JS numbers cross the bridge as Double.
    let line = BenchMarkerRelay.line(for: [
      "type": "benchMark", "name": "searchTapped", "epochMs": 1_789_434_143_650.0,
    ])

    XCTAssertEqual(line, "BENCH|searchTapped|1789434143650")
  }

  func testAcceptsAnIntegerTime() {
    let line = BenchMarkerRelay.line(for: [
      "type": "benchMark", "name": "embedFirstFrame", "epochMs": 42,
    ])

    XCTAssertEqual(line, "BENCH|embedFirstFrame|42")
  }

  func testIgnoresEverythingElse() {
    let ignored: [[String: Any?]] = [
      ["type": "searchSucceeded", "keyword": "expo", "repositories": []],
      ["type": "benchMark", "epochMs": 42.0],
      ["type": "benchMark", "name": "searchTapped"],
      ["name": "searchTapped", "epochMs": 42.0],
    ]

    for message in ignored {
      XCTAssertNil(BenchMarkerRelay.line(for: message), "\(message)")
    }
  }

  func testStartingTwiceIsHarmless() {
    BenchMarkerRelay.start()
    BenchMarkerRelay.start()
  }
}
