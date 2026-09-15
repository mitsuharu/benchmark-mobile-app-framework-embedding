package com.example.benchmark.flutter.host

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Covers the conversion from the method calls the Dart side makes to typed
 * events. No engine is started: calls are fed to `receive` directly.
 */
@RunWith(RobolectricTestRunner::class)
class RepoSearchBridgeTest {
  private val runtime = FlutterRepoSearch()

  private fun repository(
    id: Any? = 65750241,
    fullName: Any? = "expo/expo",
    stars: Any? = 51842,
    language: Any? = "TypeScript",
  ): Map<String, Any?> = mapOf("id" to id, "fullName" to fullName, "stars" to stars, "language" to language)

  private fun eventsFor(method: String, arguments: Any?): List<RepoSearchEvent> {
    val events = mutableListOf<RepoSearchEvent>()
    RepoSearchBridge(onEvent = { events += it }, runtime = runtime).start()
    runtime.receive(method, arguments)
    return events
  }

  @Test
  fun `decodes repositories`() {
    val events =
      eventsFor("searchSucceeded", mapOf("keyword" to "expo", "repositories" to listOf(repository())))

    assertEquals(
      listOf(
        RepoSearchEvent.Succeeded(
          "expo",
          listOf(SearchedRepository(65750241, "expo/expo", 51842, "TypeScript")),
        )
      ),
      events,
    )
  }

  @Test
  fun `accepts ids that arrive as Long`() {
    // Dart ints that do not fit 32 bits arrive as Long.
    val events =
      eventsFor(
        "searchSucceeded",
        mapOf("keyword" to "expo", "repositories" to listOf(repository(id = 5_000_000_000L))),
      )

    assertEquals(5_000_000_000L, (events.single() as RepoSearchEvent.Succeeded).repositories[0].id)
  }

  @Test
  fun `keeps a missing language as null`() {
    val events =
      eventsFor(
        "searchSucceeded",
        mapOf("keyword" to "expo", "repositories" to listOf(repository(language = null))),
      )

    assertNull((events.single() as RepoSearchEvent.Succeeded).repositories[0].language)
  }

  @Test
  fun `skips repositories missing required fields`() {
    val events =
      eventsFor(
        "searchSucceeded",
        mapOf(
          "keyword" to "expo",
          "repositories" to listOf(repository(), repository(id = null), repository(fullName = null), "junk"),
        ),
      )

    assertEquals(1, (events.single() as RepoSearchEvent.Succeeded).repositories.size)
  }

  @Test
  fun `decodes a failure`() {
    val events =
      eventsFor("searchFailed", mapOf("keyword" to "expo", "message" to "API rate limit exceeded"))

    assertEquals(listOf(RepoSearchEvent.Failed("expo", "API rate limit exceeded")), events)
  }

  @Test
  fun `ignores other calls`() {
    assertTrue(eventsFor("somethingElse", mapOf("keyword" to "expo")).isEmpty())
    assertTrue(eventsFor("searchSucceeded", null).isEmpty())
    assertTrue(eventsFor("mark", mapOf("name" to "searchTapped", "epochMs" to 1)).isEmpty())
  }

  @Test
  fun `close asks the host to go back`() {
    var closed = false
    runtime.onClose = { closed = true }

    runtime.receive("close", null)

    assertTrue(closed)
  }

  @Test
  fun `notifies both the listener and the lambda`() {
    val seenByListener = mutableListOf<RepoSearchEvent>()
    val seenByLambda = mutableListOf<RepoSearchEvent>()
    RepoSearchBridge(
        listener = { seenByListener += it },
        onEvent = { seenByLambda += it },
        runtime = runtime,
      )
      .start()

    runtime.receive("searchFailed", mapOf("keyword" to "expo", "message" to "boom"))

    assertEquals(1, seenByListener.size)
    assertEquals(1, seenByLambda.size)
  }

  @Test
  fun `start and stop are idempotent`() {
    val events = mutableListOf<RepoSearchEvent>()
    val bridge = RepoSearchBridge(onEvent = { events += it }, runtime = runtime)
    bridge.stop()
    bridge.start()
    bridge.start()

    runtime.receive("searchFailed", mapOf("keyword" to "expo", "message" to "boom"))
    assertEquals("a second start must not register a second listener", 1, events.size)

    bridge.stop()
    runtime.receive("searchFailed", mapOf("keyword" to "expo", "message" to "boom"))
    assertEquals(1, events.size)
  }

  @Test
  fun `sending before the engine starts is harmless`() {
    RepoSearchBridge(runtime = runtime).send(RepoSearchCommand.SetKeyword("swift"))
  }
}
