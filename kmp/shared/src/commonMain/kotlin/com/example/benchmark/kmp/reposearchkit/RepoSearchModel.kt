package com.example.benchmark.kmp.reposearchkit

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** State and behaviour of the search screen. */
internal class RepoSearchModel(
  initialKeyword: String,
  private val client: GitHubClient,
  private val channel: RepoSearchChannel = RepoSearchChannel.shared,
) {
  var keyword by mutableStateOf(initialKeyword)
    private set

  var repositories by mutableStateOf<List<Repository>>(emptyList())
    private set

  var isLoading by mutableStateOf(false)
    private set

  var errorMessage by mutableStateOf<String?>(null)
    private set

  // The keyword passed in only arrives while the screen is being created, so
  // replacing it on an open screen comes over the channel.
  private val commandListenerId =
    channel.addCommandListener { command ->
      when (command) {
        is RepoSearchCommand.SetKeyword -> {
          keyword = command.keyword
          repositories = emptyList()
          errorMessage = null
        }
      }
    }

  suspend fun search() {
    isLoading = true
    errorMessage = null
    val keyword = keyword
    try {
      val results = client.searchRepositories(keyword)
      repositories = results
      // Hand the results back to the host app.
      channel.post(RepoSearchEvent.Succeeded(keyword, results.map { it.toSearchedRepository() }))
    } catch (e: Exception) {
      val message = e.message ?: e.toString()
      repositories = emptyList()
      errorMessage = message
      channel.post(RepoSearchEvent.Failed(keyword, message))
    } finally {
      isLoading = false
    }
  }

  fun dispose() {
    channel.removeCommandListener(commandListenerId)
  }
}

private fun Repository.toSearchedRepository() =
  SearchedRepository(id = id, fullName = fullName, stars = stars, language = language)
