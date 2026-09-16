package com.example.benchmark.kmpnativeui.reposearchkit

import io.ktor.http.HttpStatusCode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.job
import kotlinx.coroutines.test.runTest

/** Covers the shared logic without rendering the native screen. */
class RepoSearchModelTest {
  private val channel = RepoSearchChannel()
  private val events = mutableListOf<RepoSearchEvent>()

  init {
    channel.addEventListener { events.add(it) }
  }

  private fun model(scope: CoroutineScope, http: StubHttp = StubHttp()) =
    RepoSearchModel(
      initialKeyword = "expo",
      client = GitHubClient(httpClient = http.client),
      channel = channel,
      scope = scope,
    )

  /**
   * Waits for the coroutine `search()` launched. The stub HTTP engine finishes
   * on a dispatcher of its own, so advancing the test scheduler would return
   * before the response arrives.
   */
  private suspend fun CoroutineScope.awaitSearch() {
    coroutineContext.job.children.toList().forEach { it.join() }
  }

  @Test
  fun startsWithTheKeywordFromTheHostAndNoResults() = runTest {
    val model = model(backgroundScope)

    assertEquals("expo", model.state.keyword)
    assertTrue(model.state.repositories.isEmpty())
    assertFalse(model.state.isLoading)
  }

  @Test
  fun listsAndReportsTheResults() = runTest {
    val model = model(backgroundScope)

    model.search()
    backgroundScope.awaitSearch()

    assertEquals(listOf("expo/expo", "a/b"), model.state.repositories.map { it.fullName })
    assertFalse(model.state.isLoading)
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
  fun tellsTheScreenAboutEveryChange() = runTest {
    val model = model(backgroundScope)
    val seen = mutableListOf<RepoSearchState>()
    model.onStateChange = { seen.add(it) }

    model.search()
    backgroundScope.awaitSearch()

    // Loading, then the results.
    assertEquals(listOf(true, false), seen.map { it.isLoading })
    assertEquals(listOf("expo/expo", "a/b"), seen.last().repositories.map { it.fullName })
  }

  @Test
  fun showsAndReportsAFailure() = runTest {
    val model =
      model(
        backgroundScope,
        StubHttp(HttpStatusCode.Forbidden, """{"message":"API rate limit exceeded"}"""),
      )

    model.search()
    backgroundScope.awaitSearch()

    assertEquals("API rate limit exceeded", model.state.errorMessage)
    assertTrue(model.state.repositories.isEmpty())
    assertFalse(model.state.isLoading)
    assertEquals(
      listOf<RepoSearchEvent>(RepoSearchEvent.Failed("expo", "API rate limit exceeded")),
      events,
    )
  }

  @Test
  fun followsAKeywordTheHostSendsWhileOpen() = runTest {
    val http = StubHttp()
    val model = model(backgroundScope, http)

    channel.send(RepoSearchCommand.SetKeyword("swift"))
    model.search()
    backgroundScope.awaitSearch()

    assertEquals("swift", model.state.keyword)
    assertEquals("swift", http.requested.single().parameters["q"])
  }

  @Test
  fun clearsThePreviousResultsWhenTheKeywordIsReplaced() = runTest {
    val model = model(backgroundScope, StubHttp(HttpStatusCode.Forbidden, """{"message":"boom"}"""))
    model.search()
    backgroundScope.awaitSearch()

    channel.send(RepoSearchCommand.SetKeyword("swift"))

    assertTrue(model.state.repositories.isEmpty())
    assertNull(model.state.errorMessage)
  }

  @Test
  fun stopsFollowingCommandsOnceDisposed() = runTest {
    val model = model(backgroundScope)

    model.dispose()
    channel.send(RepoSearchCommand.SetKeyword("swift"))

    assertEquals("expo", model.state.keyword)
  }
}
