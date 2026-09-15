package com.example.benchmark.flutter.host

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/** One repository as it arrives from the Flutter screen. */
data class SearchedRepository(
  val id: Long,
  val fullName: String,
  val stars: Int,
  val language: String?,
)

/** What the Flutter screen reports back. Mirrors `lib/src/host_channel.dart`. */
sealed interface RepoSearchEvent {
  data class Succeeded(val keyword: String, val repositories: List<SearchedRepository>) :
    RepoSearchEvent

  data class Failed(val keyword: String, val message: String) : RepoSearchEvent

  companion object {
    /** Decodes one method call from the Flutter screen, or null when it is not a result. */
    fun from(method: String, arguments: Any?): RepoSearchEvent? {
      val map = arguments as? Map<*, *> ?: return null
      val keyword = map["keyword"] as? String ?: return null
      return when (method) {
        "searchSucceeded" -> {
          val raw = map["repositories"] as? List<*> ?: emptyList<Any?>()
          Succeeded(keyword, raw.mapNotNull { it.toSearchedRepository() })
        }
        "searchFailed" -> Failed(keyword, map["message"] as? String ?: "unknown error")
        else -> null
      }
    }
  }
}

/**
 * Dart ints arrive as Int or Long depending on their size, so they are read as
 * `Number`.
 */
private fun Any?.toSearchedRepository(): SearchedRepository? {
  val json = this as? Map<*, *> ?: return null
  val id = (json["id"] as? Number)?.toLong() ?: return null
  val fullName = json["fullName"] as? String ?: return null
  return SearchedRepository(
    id = id,
    fullName = fullName,
    stars = (json["stars"] as? Number)?.toInt() ?: 0,
    language = json["language"] as? String,
  )
}

/**
 * What the host app asks the Flutter screen to do. The mirror image of
 * [RepoSearchEvent].
 */
sealed interface RepoSearchCommand {
  /** Replaces the keyword on a screen that is already open. */
  data class SetKeyword(val keyword: String) : RepoSearchCommand
}

/** The delegate-style callback. */
fun interface RepoSearchListener {
  fun onRepoSearchEvent(event: RepoSearchEvent)
}

/**
 * The host app's end of the channel, delivering events through either a
 * listener or a lambda — the same shape as the bridge the other
 * implementations ship. Flutter ships no native code of its own here, so the
 * typed bridge lives in the host app.
 */
class RepoSearchBridge(
  private val listener: RepoSearchListener? = null,
  private val onEvent: ((RepoSearchEvent) -> Unit)? = null,
  private val runtime: FlutterRepoSearch = FlutterRepoSearch.shared,
) {
  private var listenerId: UUID? = null

  fun start() {
    if (listenerId != null) return
    listenerId =
      runtime.addEventListener { event ->
        listener?.onRepoSearchEvent(event)
        onEvent?.invoke(event)
      }
  }

  fun stop() {
    listenerId?.let { id ->
      runtime.removeEventListener(id)
      listenerId = null
    }
  }

  /** Sends a command to the Flutter screen. */
  fun send(command: RepoSearchCommand) {
    runtime.send(command)
  }
}

/**
 * The Flutter engine behind the screen, started once at launch and reused by
 * every visit through [FlutterEngineCache], plus the method channel to the
 * Dart side.
 *
 * The engine keeps one Dart app alive across visits, so opening the screen
 * sends `start` to give it a fresh screen for the keyword — what React Native
 * gets from creating a new root view with new initial props.
 */
class FlutterRepoSearch {
  /** Called when the Flutter screen asks to go back to the host. */
  var onClose: (() -> Unit)? = null

  private var channel: MethodChannel? = null
  private val eventListeners = LinkedHashMap<UUID, (RepoSearchEvent) -> Unit>()

  fun start(context: Context) {
    if (channel != null) return
    val engine = FlutterEngine(context.applicationContext)
    engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
    FlutterEngineCache.getInstance().put(ENGINE_ID, engine)

    channel =
      MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
        it.setMethodCallHandler { call, result ->
          receive(call.method, call.arguments)
          result.success(null)
        }
      }
  }

  /** Resets the screen for a new visit. Call before showing the fragment. */
  fun prepareScreen(keyword: String, apiBaseUrl: String) {
    channel?.invokeMethod("start", mapOf("keyword" to keyword, "apiBaseUrl" to apiBaseUrl))
  }

  fun send(command: RepoSearchCommand) {
    when (command) {
      is RepoSearchCommand.SetKeyword ->
        channel?.invokeMethod("setKeyword", mapOf("keyword" to command.keyword))
    }
  }

  fun addEventListener(listener: (RepoSearchEvent) -> Unit): UUID =
    UUID.randomUUID().also { eventListeners[it] = listener }

  fun removeEventListener(id: UUID) {
    eventListeners.remove(id)
  }

  /**
   * Handles one call from the Dart side, on the main thread. Public so the
   * decoding can be tested without an engine.
   */
  fun receive(method: String, arguments: Any?) {
    when (method) {
      "mark" -> {
        // The Dart side takes the time; the host writes the line (AGENTS.md).
        val map = arguments as? Map<*, *> ?: return
        val name = map["name"] as? String ?: return
        val epochMs = (map["epochMs"] as? Number)?.toLong() ?: return
        BenchMarker.mark(name, epochMs)
      }
      "close" -> onClose?.invoke()
      else -> {
        val event = RepoSearchEvent.from(method, arguments) ?: return
        eventListeners.values.toList().forEach { it(event) }
      }
    }
  }

  companion object {
    const val ENGINE_ID = "repo_search"
    const val CHANNEL = "repo_search"

    val shared = FlutterRepoSearch()
  }
}
