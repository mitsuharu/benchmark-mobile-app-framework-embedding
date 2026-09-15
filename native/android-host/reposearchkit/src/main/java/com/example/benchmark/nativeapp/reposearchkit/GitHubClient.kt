package com.example.benchmark.nativeapp.reposearchkit

import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** One repository from the GitHub Search API. */
data class Repository(
  val id: Long,
  val fullName: String,
  val description: String?,
  val stars: Int,
  val language: String?,
  val htmlUrl: String,
)

class GitHubException(message: String) : Exception(message)

/** What came back over HTTP, before it is decoded. */
data class HttpResponse(val status: Int, val body: String)

/**
 * Minimal GitHub Search API client.
 * https://docs.github.com/en/rest/search/search#search-repositories
 */
class GitHubClient(
  private val baseUrl: String = DEFAULT_BASE_URL,
  private val transport: suspend (URL) -> HttpResponse = ::get,
) {
  suspend fun searchRepositories(keyword: String, perPage: Int = 20): List<Repository> {
    val query =
      listOf("q" to keyword, "sort" to "stars", "order" to "desc", "per_page" to "$perPage")
        .joinToString("&") { (name, value) -> "$name=${URLEncoder.encode(value, "UTF-8")}" }
    val response = transport(URL("${baseUrl.trimEnd('/')}/search/repositories?$query"))

    if (response.status !in 200..299) {
      // Unauthenticated search is rate limited to 10 requests / minute.
      val message = runCatching { json.decodeFromString<ErrorResponse>(response.body).message }
      throw GitHubException(
        message.getOrNull() ?: "GitHub API responded with ${response.status}"
      )
    }

    return json.decodeFromString<SearchResponse>(response.body).items.map { item ->
      Repository(
        id = item.id,
        fullName = item.fullName,
        description = item.description,
        stars = item.stargazersCount,
        language = item.language,
        htmlUrl = item.htmlUrl,
      )
    }
  }

  companion object {
    const val DEFAULT_BASE_URL = "https://api.github.com"

    private val json = Json { ignoreUnknownKeys = true }

    private suspend fun get(url: URL): HttpResponse =
      withContext(Dispatchers.IO) {
        val connection = url.openConnection() as HttpURLConnection
        try {
          connection.setRequestProperty("Accept", "application/vnd.github+json")
          connection.setRequestProperty("X-GitHub-Api-Version", "2022-11-28")
          val status = connection.responseCode
          val stream = if (status in 200..299) connection.inputStream else connection.errorStream
          HttpResponse(status, stream?.bufferedReader()?.use { it.readText() } ?: "")
        } finally {
          connection.disconnect()
        }
      }
  }
}

@Serializable
private data class SearchResponse(val items: List<Item>) {
  @Serializable
  data class Item(
    val id: Long,
    @SerialName("full_name") val fullName: String,
    val description: String? = null,
    @SerialName("stargazers_count") val stargazersCount: Int,
    val language: String? = null,
    @SerialName("html_url") val htmlUrl: String,
  )
}

@Serializable private data class ErrorResponse(val message: String? = null)
