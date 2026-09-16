package com.example.benchmark.kmpnativeui.reposearchkit

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.Url
import io.ktor.http.headersOf

internal const val SEARCH_RESPONSE =
  """
  {
    "total_count": 2,
    "items": [
      {
        "id": 65750241,
        "full_name": "expo/expo",
        "description": "An open-source framework",
        "stargazers_count": 51842,
        "language": "TypeScript",
        "html_url": "https://github.com/expo/expo"
      },
      {
        "id": 1,
        "full_name": "a/b",
        "description": null,
        "stargazers_count": 0,
        "language": null,
        "html_url": "https://github.com/a/b"
      }
    ]
  }
  """

/** A client whose every request gets the same canned answer. */
internal class StubHttp(
  private val status: HttpStatusCode = HttpStatusCode.OK,
  private val body: String = SEARCH_RESPONSE,
) {
  val requested = mutableListOf<Url>()
  val acceptHeaders = mutableListOf<String?>()

  val client =
    HttpClient(
      MockEngine { request ->
        requested += request.url
        acceptHeaders += request.headers[HttpHeaders.Accept]
        respond(body, status, headersOf(HttpHeaders.ContentType, "application/json"))
      }
    )
}
