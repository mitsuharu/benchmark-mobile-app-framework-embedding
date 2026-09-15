package com.example.benchmark.nativeapp.reposearchkit

import java.net.URL
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.fail
import org.junit.Test

class GitHubClientTest {
  private val requested = mutableListOf<URL>()

  private fun client(
    response: HttpResponse = HttpResponse(200, SEARCH_RESPONSE),
    baseUrl: String = GitHubClient.DEFAULT_BASE_URL,
  ) =
    GitHubClient(baseUrl) { url ->
      requested += url
      response
    }

  private fun URL.queryParameters(): Map<String, String> =
    query.split("&").associate { it.substringBefore("=") to it.substringAfter("=") }

  private suspend fun errorMessageOf(client: GitHubClient): String? =
    try {
      client.searchRepositories("expo")
      fail("expected an error")
      null
    } catch (e: GitHubException) {
      e.message
    }

  @Test
  fun `queries the keyword sorted by stars`() = runTest {
    client().searchRepositories("expo")

    val url = requested.single()
    assertEquals("api.github.com", url.host)
    assertEquals("/search/repositories", url.path)
    assertEquals(
      mapOf("q" to "expo", "sort" to "stars", "order" to "desc", "per_page" to "20"),
      url.queryParameters(),
    )
  }

  @Test
  fun `sends requests to the configured base url`() = runTest {
    // The benchmark build points the client at bench/mock-server.
    client(baseUrl = "http://10.0.2.2:8787").searchRepositories("expo")

    val url = requested.single()
    assertEquals("10.0.2.2", url.host)
    assertEquals(8787, url.port)
    assertEquals("/search/repositories", url.path)
  }

  @Test
  fun `encodes the keyword`() = runTest {
    client().searchRepositories("react native")

    assertEquals("react+native", requested.single().queryParameters()["q"])
  }

  @Test
  fun `maps the response onto repositories`() = runTest {
    val repositories = client().searchRepositories("expo")

    assertEquals(
      Repository(
        id = 65750241,
        fullName = "expo/expo",
        description = "An open-source framework",
        stars = 51842,
        language = "TypeScript",
        htmlUrl = "https://github.com/expo/expo",
      ),
      repositories[0],
    )
    assertEquals(2, repositories.size)
  }

  @Test
  fun `keeps null description and language as null`() = runTest {
    val repository = client().searchRepositories("expo")[1]

    assertNull(repository.description)
    assertNull(repository.language)
  }

  @Test
  fun `surfaces the api message when the request is rejected`() = runTest {
    // Unauthenticated search is rate limited to 10 requests / minute.
    val rejected = client(HttpResponse(403, """{"message":"API rate limit exceeded"}"""))

    assertEquals("API rate limit exceeded", errorMessageOf(rejected))
  }

  @Test
  fun `falls back to the status code when there is no message`() = runTest {
    assertEquals("GitHub API responded with 500", errorMessageOf(client(HttpResponse(500, "{}"))))
    assertEquals("GitHub API responded with 502", errorMessageOf(client(HttpResponse(502, ""))))
  }
}
