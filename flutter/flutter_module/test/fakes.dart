import 'package:repo_search/src/github_client.dart';
import 'package:repo_search/src/host_channel.dart';

const expoRepository = Repository(
  id: 65750241,
  fullName: 'expo/expo',
  description: 'An open-source framework',
  stars: 51842,
  language: 'TypeScript',
  htmlUrl: 'https://github.com/expo/expo',
);

const bareRepository = Repository(
  id: 1,
  fullName: 'a/b',
  description: null,
  stars: 0,
  language: null,
  htmlUrl: 'https://github.com/a/b',
);

/// Answers searches from memory and remembers what was asked.
class FakeGitHubClient extends GitHubClient {
  FakeGitHubClient({this.results = const [], this.error});

  final List<Repository> results;
  final Object? error;
  final keywords = <String>[];

  @override
  Future<List<Repository>> searchRepositories(
    String keyword, {
    int perPage = 20,
  }) async {
    keywords.add(keyword);
    if (error != null) throw error!;
    return results;
  }
}

/// Records what the screen tells the host app instead of calling into it.
class FakeHostChannel extends HostChannel {
  final succeeded = <(String, List<Repository>)>[];
  final failed = <(String, String)>[];
  final marks = <BenchMarker>[];
  int closeCount = 0;
  void Function(HostCommand command)? _onCommand;

  /// Delivers a command as if the host app had sent it.
  void send(HostCommand command) => _onCommand!(command);

  @override
  void listen(void Function(HostCommand command) onCommand) {
    _onCommand = onCommand;
  }

  @override
  void notifySearchSucceeded(String keyword, List<Repository> repositories) {
    succeeded.add((keyword, repositories));
  }

  @override
  void notifySearchFailed(String keyword, String message) {
    failed.add((keyword, message));
  }

  @override
  void close() => closeCount++;

  @override
  void mark(BenchMarker marker) => marks.add(marker);

  @override
  void markAfterFrame(BenchMarker marker) => marks.add(marker);
}
