package com.example.sample.expo.brownfield.host

import com.example.sample.expo.brownfield.reposearchkit.BenchMarkerRelay
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Covers the line the relay writes for a marker the React Native screen sends. */
class BenchMarkerRelayTest {
  @Test
  fun `formats a marker`() {
    // JS numbers cross the bridge as boxed floating point values.
    val line =
      BenchMarkerRelay.line(
        mapOf("type" to "benchMark", "name" to "searchTapped", "epochMs" to 1789434143650.0)
      )

    assertEquals("BENCH|searchTapped|1789434143650", line)
  }

  @Test
  fun `accepts an integer time`() {
    val line =
      BenchMarkerRelay.line(mapOf("type" to "benchMark", "name" to "embedFirstFrame", "epochMs" to 42))

    assertEquals("BENCH|embedFirstFrame|42", line)
  }

  @Test
  fun `ignores everything else`() {
    assertNull(BenchMarkerRelay.line(mapOf("type" to "searchSucceeded", "keyword" to "expo")))
    assertNull(BenchMarkerRelay.line(mapOf("type" to "benchMark", "epochMs" to 42.0)))
    assertNull(BenchMarkerRelay.line(mapOf("type" to "benchMark", "name" to "searchTapped")))
    assertNull(BenchMarkerRelay.line(mapOf("name" to "searchTapped", "epochMs" to 42.0)))
  }
}
