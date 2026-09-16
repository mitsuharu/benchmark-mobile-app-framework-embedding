package com.example.benchmark.kmpnativeui.reposearchkit

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Covers the channel between the host app and the search screen. */
class RepoSearchBridgeTest {
  private val channel = RepoSearchChannel()
  private val repository = SearchedRepository(65750241, "expo/expo", 51842, "TypeScript")

  private fun bridge(
    listener: RepoSearchListener? = null,
    onEvent: ((RepoSearchEvent) -> Unit)? = null,
  ) = RepoSearchBridge(channel, listener, onEvent)

  @Test
  fun notifiesBothTheListenerAndTheLambda() {
    val seenByListener = mutableListOf<RepoSearchEvent>()
    val seenByLambda = mutableListOf<RepoSearchEvent>()
    val bridge = bridge(listener = { seenByListener.add(it) }, onEvent = { seenByLambda.add(it) })
    bridge.start()

    channel.post(RepoSearchEvent.Succeeded("expo", listOf(repository)))

    assertEquals(listOf<RepoSearchEvent>(RepoSearchEvent.Succeeded("expo", listOf(repository))), seenByListener)
    assertEquals(seenByListener, seenByLambda)
  }

  @Test
  fun deliversNothingBeforeStart() {
    val events = mutableListOf<RepoSearchEvent>()
    bridge(onEvent = { events.add(it) })

    channel.post(RepoSearchEvent.Failed("expo", "boom"))

    assertTrue(events.isEmpty())
  }

  @Test
  fun deliversNothingAfterStop() {
    val events = mutableListOf<RepoSearchEvent>()
    val bridge = bridge(onEvent = { events.add(it) })
    bridge.start()
    bridge.stop()

    channel.post(RepoSearchEvent.Failed("expo", "boom"))

    assertTrue(events.isEmpty())
  }

  @Test
  fun startAndStopAreIdempotent() {
    val events = mutableListOf<RepoSearchEvent>()
    val bridge = bridge(onEvent = { events.add(it) })
    bridge.stop()
    bridge.start()
    bridge.start()

    channel.post(RepoSearchEvent.Failed("expo", "boom"))

    assertEquals(1, events.size, "a second start must not register a second listener")
    bridge.stop()
    bridge.stop()
  }

  @Test
  fun sendsCommandsToTheScreen() {
    val commands = mutableListOf<RepoSearchCommand>()
    channel.addCommandListener { commands.add(it) }

    bridge().send(RepoSearchCommand.SetKeyword("swift"))

    assertEquals(listOf<RepoSearchCommand>(RepoSearchCommand.SetKeyword("swift")), commands)
  }

  @Test
  fun sendingWithNoScreenOpenIsHarmless() {
    bridge().send(RepoSearchCommand.SetKeyword("swift"))
  }
}
