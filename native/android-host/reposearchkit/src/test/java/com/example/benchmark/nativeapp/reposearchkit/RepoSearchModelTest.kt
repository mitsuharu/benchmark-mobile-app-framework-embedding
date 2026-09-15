package com.example.benchmark.nativeapp.reposearchkit

import java.net.URL
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Covers the search screen's behaviour without rendering it. */
class RepoSearchModelTest {
  private val channel = RepoSearchChannel()
  private val events = mutableListOf<RepoSearchEvent>()
  private val requested = mutableListOf<URL>()

  init {
    channel.addEventListener { events += it }
  }

  private fun model(response: HttpResponse = HttpResponse(200, SEARCH_RESPONSE)) =
    RepoSearchModel(
      initialKeyword = "expo",
      client =
        GitHubClient { url ->
          requested += url
          response
        },
      channel = channel,
    )

  @Test
  fun `starts with the keyword from the host and no results`() {
    val model = model()

    assertEquals("expo", model.keyword)
    assertTrue(model.repositories.isEmpty())
    assertFalse(model.isLoading)
  }

  @Test
  fun `lists and reports the results`() = runTest {
    val model = model()

    model.search()

    assertEquals(listOf("expo/expo", "a/b"), model.repositories.map { it.fullName })
    assertFalse(model.isLoading)
    assertEquals(
      listOf(
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
  fun `shows and reports a failure`() = runTest {
    val model = model(HttpResponse(403, """{"message":"API rate limit exceeded"}"""))

    model.search()

    assertEquals("API rate limit exceeded", model.errorMessage)
    assertTrue(model.repositories.isEmpty())
    assertFalse(model.isLoading)
    assertEquals(listOf(RepoSearchEvent.Failed("expo", "API rate limit exceeded")), events)
  }

  @Test
  fun `follows a keyword the host sends while open`() = runTest {
    val model = model()

    channel.send(RepoSearchCommand.SetKeyword("swift"))
    model.search()

    assertEquals("swift", model.keyword)
    assertTrue(requested.single().query.contains("q=swift"))
  }

  @Test
  fun `clears the previous results when the keyword is replaced`() = runTest {
    val model = model(HttpResponse(403, """{"message":"boom"}"""))
    model.search()

    channel.send(RepoSearchCommand.SetKeyword("swift"))

    assertTrue(model.repositories.isEmpty())
    assertNull(model.errorMessage)
  }

  @Test
  fun `stops following commands once disposed`() {
    val model = model()

    model.dispose()
    channel.send(RepoSearchCommand.SetKeyword("swift"))

    assertEquals("expo", model.keyword)
  }
}
