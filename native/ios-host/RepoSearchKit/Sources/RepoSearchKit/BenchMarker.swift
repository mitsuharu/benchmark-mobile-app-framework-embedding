import Foundation
import os

/// The search screen's copy of the host app's `BenchMarker`: the embedded side
/// of every implementation reports its own markers (see AGENTS.md).
enum BenchMarker {
  private static let logger = Logger(subsystem: "bench", category: "marker")

  static func mark(_ name: String, at date: Date = Date()) {
    let epochMs = Int64((date.timeIntervalSince1970 * 1000).rounded())
    logger.notice("BENCH|\(name, privacy: .public)|\(epochMs, privacy: .public)")
  }

  /// Marks once the frame that is being built has been committed: SwiftUI
  /// calls `onAppear` / `onChange` before the frame, and the next turn of the
  /// main loop comes after it.
  static func markAfterFrame(_ name: String) {
    DispatchQueue.main.async { mark(name) }
  }
}
