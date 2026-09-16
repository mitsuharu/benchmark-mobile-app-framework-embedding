package com.example.benchmark.kmpnativeui.reposearchkit

import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.statement.bodyAsText
import io.ktor.http.isSuccess
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

/**
 * Minimal GitHub Search API client.
 * https://docs.github.com/en/rest/search/search#search-repositories
 *
 * `HttpClient()` picks the engine each platform ships: OkHttp on Android,
 * NSURLSession on iOS.
 */
class GitHubClient(
  private val baseUrl: String = DEFAULT_BASE_URL,
  private val httpClient: HttpClient = HttpClient(),
) {
  suspend fun searchRepositories(keyword: String, perPage: Int = 20): List<Repository> {
    val response =
      httpClient.get("${baseUrl.trimEnd('/')}/search/repositories") {
        parameter("q", keyword)
        parameter("sort", "stars")
        parameter("order", "desc")
        parameter("per_page", perPage)
        header("Accept", "application/vnd.github+json")
        header("X-GitHub-Api-Version", "2022-11-28")
      }
    val body = response.bodyAsText()

    if (!response.status.isSuccess()) {
      // Unauthenticated search is rate limited to 10 requests / minute.
      val message = runCatching { json.decodeFromString<ErrorResponse>(body).message }
      throw GitHubException(
        message.getOrNull() ?: "GitHub API responded with ${response.status.value}"
      )
    }

    return json.decodeFromString<SearchResponse>(body).items.map { item ->
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
