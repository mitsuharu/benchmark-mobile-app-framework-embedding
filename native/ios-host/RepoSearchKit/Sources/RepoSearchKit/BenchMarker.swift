import Foundation
import QuartzCore
import os

/// The search screen's copy of the host app's `BenchMarker`: the embedded side
/// of every implementation reports its own markers (see AGENTS.md).
enum BenchMarker {
  private static let logger = Logger(subsystem: "bench", category: "marker")

  static func mark(_ name: String, at date: Date = Date()) {
    let epochMs = Int64((date.timeIntervalSince1970 * 1000).rounded())
    logger.notice("BENCH|\(name, privacy: .public)|\(epochMs, privacy: .public)")
    // On a physical iPhone the app log carries only the process's own output,
    // not unified logging, so the line goes to stderr as well.
    fputs("BENCH|\(name)|\(epochMs)\n", stderr)
  }

  /// Marks at the frame boundary after the change has been drawn: SwiftUI
  /// calls `onAppear` / `onChange` before the frame, the next display tick
  /// starts the frame that draws it, and the one after it means the change is
  /// on screen. Every implementation waits for the same two frame boundaries
  /// (see AGENTS.md), so the numbers line up.
  static func markAfterFrame(_ name: String) {
    FrameWaiter.wait(frames: 2) { mark(name) }
  }
}

/// Runs a block after a number of display frames.
private final class FrameWaiter: NSObject {
  /// Keeps each waiter alive until it has run; CADisplayLink does not retain
  /// its target.
  private static var pending: [FrameWaiter] = []

  private var remaining: Int
  private let body: () -> Void
  private var link: CADisplayLink?

  private init(frames: Int, body: @escaping () -> Void) {
    self.remaining = frames
    self.body = body
  }

  static func wait(frames: Int, then body: @escaping () -> Void) {
    let waiter = FrameWaiter(frames: frames, body: body)
    pending.append(waiter)
    let link = CADisplayLink(target: waiter, selector: #selector(tick))
    waiter.link = link
    link.add(to: .main, forMode: .common)
  }

  @objc private func tick() {
    remaining -= 1
    guard remaining <= 0 else { return }
    link?.invalidate()
    link = nil
    body()
    Self.pending.removeAll { $0 === self }
  }
}
