import Foundation

/// Answers every request of a session with a canned response, so the search
/// client can be tested without a network.
final class StubURLProtocol: URLProtocol {
  struct Response {
    var status: Int = 200
    var body: String
  }

  static var respond: ((URLRequest) -> Response)?
  static private(set) var requests: [URLRequest] = []

  static func session(_ respond: @escaping (URLRequest) -> Response) -> URLSession {
    self.respond = respond
    requests = []
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.requests.append(request)
    let response = Self.respond?(request) ?? Response(status: 500, body: "{}")
    let http = HTTPURLResponse(
      url: request.url!,
      statusCode: response.status,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!
    client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(response.body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

enum Fixture {
  static let searchResponse = """
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
}
