package com.example.benchmark.kmp.reposearchkit

import io.ktor.http.HttpStatusCode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

/** Covers the search screen's behaviour without rendering it. */
class RepoSearchModelTest {
  private val channel = RepoSearchChannel()
  private val events = mutableListOf<RepoSearchEvent>()

  init {
    channel.addEventListener { events.add(it) }
  }

  private fun model(http: StubHttp = StubHttp()) =
    RepoSearchModel(
      initialKeyword = "expo",
      client = GitHubClient(httpClient = http.client),
      channel = channel,
    )

  @Test
  fun startsWithTheKeywordFromTheHostAndNoResults() {
    val model = model()

    assertEquals("expo", model.keyword)
    assertTrue(model.repositories.isEmpty())
    assertFalse(model.isLoading)
  }

  @Test
  fun listsAndReportsTheResults() = runTest {
    val model = model()

    model.search()

    assertEquals(listOf("expo/expo", "a/b"), model.repositories.map { it.fullName })
    assertFalse(model.isLoading)
    assertEquals(
      listOf<RepoSearchEvent>(
        RepoSearchEvent.Succeeded(
          "expo",
          listOf(
            SearchedRepository(65750241, "expo/expo", 51842, "TypeScript"),
            SearchedRepository(1, "a/b", 0, null),
          ),
        )
      ),
      events,
    )
  }

  @Test
  fun showsAndReportsAFailure() = runTest {
    val model = model(StubHttp(HttpStatusCode.Forbidden, """{"message":"API rate limit exceeded"}"""))

    model.search()

    assertEquals("API rate limit exceeded", model.errorMessage)
    assertTrue(model.repositories.isEmpty())
    assertFalse(model.isLoading)
    assertEquals(
      listOf<RepoSearchEvent>(RepoSearchEvent.Failed("expo", "API rate limit exceeded")),
      events,
    )
  }

  @Test
  fun followsAKeywordTheHostSendsWhileOpen() = runTest {
    val http = StubHttp()
    val model = model(http)

    channel.send(RepoSearchCommand.SetKeyword("swift"))
    model.search()

    assertEquals("swift", model.keyword)
    assertEquals("swift", http.requested.single().parameters["q"])
  }

  @Test
  fun clearsThePreviousResultsWhenTheKeywordIsReplaced() = runTest {
    val model = model(StubHttp(HttpStatusCode.Forbidden, """{"message":"boom"}"""))
    model.search()

    channel.send(RepoSearchCommand.SetKeyword("swift"))

    assertTrue(model.repositories.isEmpty())
    assertNull(model.errorMessage)
  }

  @Test
  fun stopsFollowingCommandsOnceDisposed() {
    val model = model()

    model.dispose()
    channel.send(RepoSearchCommand.SetKeyword("swift"))

    assertEquals("expo", model.keyword)
  }

  @Test
  fun groupsStarCountsByThousands() {
    assertEquals("0", groupThousands(0))
    assertEquals("999", groupThousands(999))
    assertEquals("51,842", groupThousands(51842))
    assertEquals("1,234,567", groupThousands(1234567))
  }
}
