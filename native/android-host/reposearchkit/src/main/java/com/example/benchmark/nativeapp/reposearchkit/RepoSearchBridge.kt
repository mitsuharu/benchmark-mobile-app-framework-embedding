package com.example.benchmark.nativeapp.reposearchkit

import java.util.UUID

/** One repository as the search screen reports it to the host. */
data class SearchedRepository(
  val id: Long,
  val fullName: String,
  val stars: Int,
  val language: String?,
)

/** What the search screen reports back. */
sealed interface RepoSearchEvent {
  data class Succeeded(val keyword: String, val repositories: List<SearchedRepository>) :
    RepoSearchEvent

  data class Failed(val keyword: String, val message: String) : RepoSearchEvent
}

/**
 * What the host app asks the search screen to do. The mirror image of
 * [RepoSearchEvent].
 */
sealed interface RepoSearchCommand {
  /**
   * Replaces the keyword on a screen that is already open. The keyword given
   * to [RepoSearchScreen] only reaches the screen while it is being created.
   */
  data class SetKeyword(val keyword: String) : RepoSearchCommand
}

/** The delegate-style callback. */
fun interface RepoSearchListener {
  fun onRepoSearchEvent(event: RepoSearchEvent)
}

/**
 * The host app's end of the channel, delivering events through either a
 * listener or a lambda.
 *
 * It has the same shape as the bridge the other implementations ship with
 * their embedded screen, so the host apps read the same. Here both ends are
 * Kotlin in one process, so values travel as they are: there is no wire format
 * to encode, which is the baseline the other channels are measured against.
 *
 * Main thread only, like the UI on both ends.
 */
class RepoSearchBridge
internal constructor(
  private val channel: RepoSearchChannel,
  private val listener: RepoSearchListener?,
  private val onEvent: ((RepoSearchEvent) -> Unit)?,
) {
  constructor(
    listener: RepoSearchListener? = null,
    onEvent: ((RepoSearchEvent) -> Unit)? = null,
  ) : this(RepoSearchChannel.shared, listener, onEvent)

  private var listenerId: UUID? = null

  fun start() {
    if (listenerId != null) return
    listenerId =
      channel.addEventListener { event ->
        listener?.onRepoSearchEvent(event)
        onEvent?.invoke(event)
      }
  }

  fun stop() {
    listenerId?.let { id ->
      channel.removeEventListener(id)
      listenerId = null
    }
  }

  /** Sends a command to the search screen. It is dropped when no screen is open. */
  fun send(command: RepoSearchCommand) {
    channel.send(command)
  }
}

/** The in-process message bus between the host app and the search screen. */
internal class RepoSearchChannel {
  private val eventListeners = LinkedHashMap<UUID, (RepoSearchEvent) -> Unit>()
  private val commandListeners = LinkedHashMap<UUID, (RepoSearchCommand) -> Unit>()

  fun addEventListener(listener: (RepoSearchEvent) -> Unit): UUID =
    UUID.randomUUID().also { eventListeners[it] = listener }

  fun removeEventListener(id: UUID) {
    eventListeners.remove(id)
  }

  fun post(event: RepoSearchEvent) {
    eventListeners.values.toList().forEach { it(event) }
  }

  fun addCommandListener(listener: (RepoSearchCommand) -> Unit): UUID =
    UUID.randomUUID().also { commandListeners[it] = listener }

  fun removeCommandListener(id: UUID) {
    commandListeners.remove(id)
  }

  fun send(command: RepoSearchCommand) {
    commandListeners.values.toList().forEach { it(command) }
  }

  companion object {
    val shared = RepoSearchChannel()
  }
}
