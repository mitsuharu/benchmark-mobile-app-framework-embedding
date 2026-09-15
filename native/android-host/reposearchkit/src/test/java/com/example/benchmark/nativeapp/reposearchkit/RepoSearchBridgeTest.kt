package com.example.benchmark.nativeapp.reposearchkit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Covers the channel between the host app and the search screen. */
class RepoSearchBridgeTest {
  private val channel = RepoSearchChannel()
  private val repository = SearchedRepository(65750241, "expo/expo", 51842, "TypeScript")

  private fun bridge(
    listener: RepoSearchListener? = null,
    onEvent: ((RepoSearchEvent) -> Unit)? = null,
  ) = RepoSearchBridge(channel, listener, onEvent)

  @Test
  fun `notifies both the listener and the lambda`() {
    val seenByListener = mutableListOf<RepoSearchEvent>()
    val seenByLambda = mutableListOf<RepoSearchEvent>()
    val bridge =
      bridge(listener = { seenByListener += it }, onEvent = { seenByLambda += it })
    bridge.start()

    channel.post(RepoSearchEvent.Succeeded("expo", listOf(repository)))

    assertEquals(listOf(RepoSearchEvent.Succeeded("expo", listOf(repository))), seenByListener)
    assertEquals(seenByListener, seenByLambda)
  }

  @Test
  fun `delivers nothing before start`() {
    val events = mutableListOf<RepoSearchEvent>()
    bridge(onEvent = { events += it })

    channel.post(RepoSearchEvent.Failed("expo", "boom"))

    assertTrue(events.isEmpty())
  }

  @Test
  fun `delivers nothing after stop`() {
    val events = mutableListOf<RepoSearchEvent>()
    val bridge = bridge(onEvent = { events += it })
    bridge.start()
    bridge.stop()

    channel.post(RepoSearchEvent.Failed("expo", "boom"))

    assertTrue(events.isEmpty())
  }

  @Test
  fun `start and stop are idempotent`() {
    val events = mutableListOf<RepoSearchEvent>()
    val bridge = bridge(onEvent = { events += it })
    bridge.stop()
    bridge.start()
    bridge.start()

    channel.post(RepoSearchEvent.Failed("expo", "boom"))

    assertEquals("a second start must not register a second listener", 1, events.size)
    bridge.stop()
    bridge.stop()
  }

  @Test
  fun `sends commands to the screen`() {
    val commands = mutableListOf<RepoSearchCommand>()
    channel.addCommandListener { commands += it }

    bridge().send(RepoSearchCommand.SetKeyword("swift"))

    assertEquals(listOf(RepoSearchCommand.SetKeyword("swift")), commands)
  }

  @Test
  fun `sending with no screen open is harmless`() {
    bridge().send(RepoSearchCommand.SetKeyword("swift"))
  }
}
