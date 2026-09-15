package com.example.benchmark.kmp.reposearchkit

import io.ktor.http.HttpStatusCode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlinx.coroutines.test.runTest

class GitHubClientTest {
  private suspend fun errorMessageOf(http: StubHttp): String? =
    assertFailsWith<GitHubException> { GitHubClient(httpClient = http.client).searchRepositories("expo") }
      .message

  @Test
  fun queriesTheKeywordSortedByStars() = runTest {
    val http = StubHttp()

    GitHubClient(httpClient = http.client).searchRepositories("expo")

    val url = http.requested.single()
    assertEquals("api.github.com", url.host)
    assertEquals("/search/repositories", url.encodedPath)
    assertEquals("expo", url.parameters["q"])
    assertEquals("stars", url.parameters["sort"])
    assertEquals("desc", url.parameters["order"])
    assertEquals("20", url.parameters["per_page"])
    assertEquals("application/vnd.github+json", http.acceptHeaders.single())
  }

  @Test
  fun sendsRequestsToTheConfiguredBaseUrl() = runTest {
    // The benchmark build points the client at bench/mock-server.
    val http = StubHttp()

    GitHubClient("http://10.0.2.2:8787", http.client).searchRepositories("expo")

    val url = http.requested.single()
    assertEquals("10.0.2.2", url.host)
    assertEquals(8787, url.port)
    assertEquals("/search/repositories", url.encodedPath)
  }

  @Test
  fun mapsTheResponseOntoRepositories() = runTest {
    val repositories = GitHubClient(httpClient = StubHttp().client).searchRepositories("expo")

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
  fun keepsNullDescriptionAndLanguageAsNull() = runTest {
    val repository = GitHubClient(httpClient = StubHttp().client).searchRepositories("expo")[1]

    assertNull(repository.description)
    assertNull(repository.language)
  }

  @Test
  fun surfacesTheApiMessageWhenTheRequestIsRejected() = runTest {
    // Unauthenticated search is rate limited to 10 requests / minute.
    val rejected = StubHttp(HttpStatusCode.Forbidden, """{"message":"API rate limit exceeded"}""")

    assertEquals("API rate limit exceeded", errorMessageOf(rejected))
  }

  @Test
  fun fallsBackToTheStatusCodeWhenThereIsNoMessage() = runTest {
    assertEquals(
      "GitHub API responded with 500",
      errorMessageOf(StubHttp(HttpStatusCode.InternalServerError, "{}")),
    )
    assertEquals(
      "GitHub API responded with 502",
      errorMessageOf(StubHttp(HttpStatusCode.BadGateway, "")),
    )
  }
}
