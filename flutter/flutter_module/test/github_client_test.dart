import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repo_search/src/github_client.dart';

const _searchResponse = {
  'total_count': 2,
  'items': [
    {
      'id': 65750241,
      'full_name': 'expo/expo',
      'description': 'An open-source framework',
      'stargazers_count': 51842,
      'language': 'TypeScript',
      'html_url': 'https://github.com/expo/expo',
    },
    {
      'id': 1,
      'full_name': 'a/b',
      'description': null,
      'stargazers_count': 0,
      'language': null,
      'html_url': 'https://github.com/a/b',
    },
  ],
};

void main() {
  late List<http.Request> requests;

  GitHubClient client({
    String baseUrl = GitHubClient.defaultBaseUrl,
    int status = 200,
    Object body = _searchResponse,
  }) {
    requests = [];
    return GitHubClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          body is String ? body : jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }

  test('queries the keyword sorted by stars', () async {
    await client().searchRepositories('expo');

    final url = requests.single.url;
    expect(url.host, 'api.github.com');
    expect(url.path, '/search/repositories');
    expect(url.queryParameters, {
      'q': 'expo',
      'sort': 'stars',
      'order': 'desc',
      'per_page': '20',
    });
    expect(requests.single.headers['Accept'], 'application/vnd.github+json');
  });

  test('sends requests to the configured base url', () async {
    // The benchmark build points the client at bench/mock-server.
    await client(baseUrl: 'http://127.0.0.1:8787/').searchRepositories('expo');

    final url = requests.single.url;
    expect(url.origin, 'http://127.0.0.1:8787');
    expect(url.path, '/search/repositories');
  });

  test('maps the response onto repositories', () async {
    final repositories = await client().searchRepositories('expo');

    expect(repositories, hasLength(2));
    expect(
      repositories.first,
      const Repository(
        id: 65750241,
        fullName: 'expo/expo',
        description: 'An open-source framework',
        stars: 51842,
        language: 'TypeScript',
        htmlUrl: 'https://github.com/expo/expo',
      ),
    );
  });

  test('keeps null description and language as null', () async {
    final repository = (await client().searchRepositories('expo'))[1];

    expect(repository.description, isNull);
    expect(repository.language, isNull);
  });

  test('surfaces the API message when the request is rejected', () async {
    // Unauthenticated search is rate limited to 10 requests / minute.
    final rejected = client(
      status: 403,
      body: {'message': 'API rate limit exceeded'},
    );

    expect(
      () => rejected.searchRepositories('expo'),
      throwsA(
        isA<GitHubException>().having(
          (e) => e.message,
          'message',
          'API rate limit exceeded',
        ),
      ),
    );
  });

  test('falls back to the status code when there is no message', () async {
    for (final (status, body) in [(500, '{}'), (502, '')]) {
      expect(
        () => client(status: status, body: body).searchRepositories('expo'),
        throwsA(
          isA<GitHubException>().having(
            (e) => e.message,
            'message',
            'GitHub API responded with $status',
          ),
        ),
      );
    }
  });
}
