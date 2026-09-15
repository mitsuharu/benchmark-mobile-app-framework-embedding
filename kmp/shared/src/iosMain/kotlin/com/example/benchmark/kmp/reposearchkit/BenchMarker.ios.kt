package com.example.benchmark.kmp.reposearchkit

import kotlinx.cinterop.ExperimentalForeignApi
import platform.Foundation.NSDate
import platform.Foundation.NSLog
import platform.Foundation.timeIntervalSince1970
import platform.posix.fputs
import platform.posix.stderr

internal actual fun epochMillis(): Long = (NSDate().timeIntervalSince1970 * 1000).toLong()

@OptIn(ExperimentalForeignApi::class)
internal actual fun writeMarker(line: String) {
  // The line is passed as the format itself: a Kotlin String handed to NSLog's
  // variadic `%@` is not bridged to an NSString and crashes. NSLog lines are
  // public in unified logging, unlike os_log interpolations.
  NSLog(line.replace("%", "%%"))
  // On a physical iPhone the app log carries only the process's own output,
  // not unified logging, so the line goes to stderr as well.
  fputs("$line\n", stderr)
}
