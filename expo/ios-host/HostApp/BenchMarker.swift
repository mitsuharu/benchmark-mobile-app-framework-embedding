import Foundation
import os

/// Emits the benchmark markers described in AGENTS.md.
///
/// The benchmark runner reads these lines from the app log, so the format is
/// part of the contract: `BENCH|<name>|<epochMs>`.
enum BenchMarker {
  private static let logger = Logger(subsystem: "bench", category: "marker")
  private static var didMarkLaunch = false

  static func mark(_ name: String, at date: Date = Date()) {
    let epochMs = Int64((date.timeIntervalSince1970 * 1000).rounded())
    // Interpolated values are redacted as <private> in release builds unless
    // they are explicitly public.
    logger.notice("BENCH|\(name, privacy: .public)|\(epochMs, privacy: .public)")
  }

  /// Marks the first frame of the host screen, together with the moment the
  /// process started. Only the first call counts.
  static func markLaunch() {
    guard !didMarkLaunch else { return }
    didMarkLaunch = true
    // onAppear runs before the frame is committed; the next turn of the main
    // loop comes after it.
    DispatchQueue.main.async {
      if let processStart = processStartDate() {
        mark("processStart", at: processStart)
      }
      mark("hostFirstFrame")
    }
  }

  /// When the kernel started this process, which is where a cold start begins.
  static func processStartDate() -> Date? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else {
      return nil
    }
    let start = info.kp_proc.p_un.__p_starttime
    return Date(
      timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000
    )
  }
}
