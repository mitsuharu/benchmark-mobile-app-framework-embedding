package com.example.benchmark.kmp.reposearchkit

import platform.Foundation.NSDate
import platform.Foundation.NSLog
import platform.Foundation.timeIntervalSince1970

internal actual fun epochMillis(): Long = (NSDate().timeIntervalSince1970 * 1000).toLong()

internal actual fun writeMarker(line: String) {
  // The line is passed as the format itself: a Kotlin String handed to NSLog's
  // variadic `%@` is not bridged to an NSString and crashes. NSLog lines are
  // public in unified logging, unlike os_log interpolations.
  NSLog(line.replace("%", "%%"))
}
