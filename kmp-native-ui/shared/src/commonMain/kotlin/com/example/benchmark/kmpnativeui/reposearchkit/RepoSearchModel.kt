package com.example.benchmark.kmpnativeui.reposearchkit

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/** Everything the search screen draws. */
data class RepoSearchState(
  val keyword: String,
  val repositories: List<Repository> = emptyList(),
  val isLoading: Boolean = false,
  val errorMessage: String? = null,
)

/**
 * State and behaviour of the search screen, shared by both platforms.
 *
 * The screen itself is written natively (SwiftUI / Jetpack Compose), so the
 * state is a plain value plus a callback rather than a Compose or Flow type:
 * both UIs subscribe the same way and nothing here depends on a UI toolkit.
 *
 * Main thread only, like the UI on both ends.
 */
class RepoSearchModel
internal constructor(
  initialKeyword: String,
  private val client: GitHubClient,
  private val channel: RepoSearchChannel,
  private val scope: CoroutineScope,
) {
  /** What the hosts use: one visit to the screen, searching `apiBaseUrl`. */
  constructor(
    keyword: String,
    apiBaseUrl: String,
  ) : this(keyword, GitHubClient(apiBaseUrl), RepoSearchChannel.shared, MainScope())

  var state: RepoSearchState = RepoSearchState(keyword = initialKeyword)
    private set

  /** Called on the main thread after every change to [state]. */
  var onStateChange: ((RepoSearchState) -> Unit)? = null

  // The keyword passed in only arrives while the screen is being created, so
  // replacing it on an open screen comes over the channel.
  private val commandListenerId =
    channel.addCommandListener { command ->
      when (command) {
        is RepoSearchCommand.SetKeyword ->
          update(
            state.copy(
              keyword = command.keyword,
              repositories = emptyList(),
              errorMessage = null,
            )
          )
      }
    }

  /** Searches for the current keyword and hands the result to the host app. */
  fun search() {
    if (state.isLoading) return
    update(state.copy(isLoading = true, errorMessage = null))
    val keyword = state.keyword
    scope.launch {
      try {
        val results = client.searchRepositories(keyword)
        update(state.copy(repositories = results, isLoading = false))
        channel.post(
          RepoSearchEvent.Succeeded(keyword, results.map { it.toSearchedRepository() })
        )
      } catch (e: Exception) {
        val message = e.message ?: e.toString()
        update(state.copy(repositories = emptyList(), isLoading = false, errorMessage = message))
        channel.post(RepoSearchEvent.Failed(keyword, message))
      }
    }
  }

  fun dispose() {
    channel.removeCommandListener(commandListenerId)
    onStateChange = null
    scope.cancel()
  }

  private fun update(next: RepoSearchState) {
    state = next
    onStateChange?.invoke(next)
  }
}

private fun Repository.toSearchedRepository() =
  SearchedRepository(id = id, fullName = fullName, stars = stars, language = language)
