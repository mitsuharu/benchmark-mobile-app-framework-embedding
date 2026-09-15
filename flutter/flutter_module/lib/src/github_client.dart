import 'dart:convert';

import 'package:http/http.dart' as http;

/// One repository from the GitHub Search API.
class Repository {
  const Repository({
    required this.id,
    required this.fullName,
    required this.description,
    required this.stars,
    required this.language,
    required this.htmlUrl,
  });

  factory Repository.fromJson(Map<String, dynamic> json) => Repository(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    description: json['description'] as String?,
    stars: json['stargazers_count'] as int,
    language: json['language'] as String?,
    htmlUrl: json['html_url'] as String,
  );

  final int id;
  final String fullName;
  final String? description;
  final int stars;
  final String? language;
  final String htmlUrl;

  @override
  bool operator ==(Object other) =>
      other is Repository &&
      other.id == id &&
      other.fullName == fullName &&
      other.description == description &&
      other.stars == stars &&
      other.language == language &&
      other.htmlUrl == htmlUrl;

  @override
  int get hashCode =>
      Object.hash(id, fullName, description, stars, language, htmlUrl);
}

class GitHubException implements Exception {
  const GitHubException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Minimal GitHub Search API client.
/// https://docs.github.com/en/rest/search/search#search-repositories
class GitHubClient {
  GitHubClient({this.baseUrl = defaultBaseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static const defaultBaseUrl = 'https://api.github.com';

  /// Where to send requests. The benchmark build points this at
  /// bench/mock-server.
  final String baseUrl;

  final http.Client _http;

  Future<List<Repository>> searchRepositories(
    String keyword, {
    int perPage = 20,
  }) async {
    final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/search/repositories').replace(
      queryParameters: {
        'q': keyword,
        'sort': 'stars',
        'order': 'desc',
        'per_page': '$perPage',
      },
    );

    final response = await _http.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Unauthenticated search is rate limited to 10 requests / minute.
      throw GitHubException(
        _messageOf(body) ?? 'GitHub API responded with ${response.statusCode}',
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['items'] as List<dynamic>)
        .map((item) => Repository.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static String? _messageOf(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['message'] as String?;
    } on FormatException {
      return null;
    }
  }
}
