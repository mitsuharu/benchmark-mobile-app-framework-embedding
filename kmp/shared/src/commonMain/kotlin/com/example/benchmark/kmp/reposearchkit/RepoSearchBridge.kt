package com.example.benchmark.kmp.reposearchkit

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
   * to the screen only reaches it while it is being created.
   */
  data class SetKeyword(val keyword: String) : RepoSearchCommand
}

/** The delegate-style callback. A protocol on the Swift side. */
fun interface RepoSearchListener {
  fun onRepoSearchEvent(event: RepoSearchEvent)
}

/**
 * The host app's end of the channel, delivering events through either a
 * listener or a lambda. The same API from Swift and from Kotlin.
 *
 * The screen and the host share one process and one Kotlin runtime, so events
 * travel as Kotlin objects; on iOS they cross into Swift through the
 * Objective-C interop that Kotlin/Native generates, without any serialization.
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

  private var listenerId: Long? = null

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
  private var nextId = 0L
  private val eventListeners = LinkedHashMap<Long, (RepoSearchEvent) -> Unit>()
  private val commandListeners = LinkedHashMap<Long, (RepoSearchCommand) -> Unit>()

  fun addEventListener(listener: (RepoSearchEvent) -> Unit): Long =
    nextId++.also { eventListeners[it] = listener }

  fun removeEventListener(id: Long) {
    eventListeners.remove(id)
  }

  fun post(event: RepoSearchEvent) {
    eventListeners.values.toList().forEach { it(event) }
  }

  fun addCommandListener(listener: (RepoSearchCommand) -> Unit): Long =
    nextId++.also { commandListeners[it] = listener }

  fun removeCommandListener(id: Long) {
    commandListeners.remove(id)
  }

  fun send(command: RepoSearchCommand) {
    commandListeners.values.toList().forEach { it(command) }
  }

  companion object {
    val shared = RepoSearchChannel()
  }
}
