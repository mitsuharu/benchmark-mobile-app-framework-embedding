import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repo_search/main.dart';
import 'package:repo_search/src/github_client.dart';
import 'package:repo_search/src/host_channel.dart';
import 'package:repo_search/src/repo_search_screen.dart';

import 'fakes.dart';

void main() {
  late FakeHostChannel host;
  late StreamController<String> keywordChanges;

  setUp(() {
    host = FakeHostChannel();
    keywordChanges = StreamController<String>.broadcast();
  });

  tearDown(() => keywordChanges.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    String keyword = 'expo',
    GitHubClient? client,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: RepoSearchScreen(
          initialKeyword: keyword,
          client: client ?? FakeGitHubClient(),
          host: host,
          keywordChanges: keywordChanges.stream,
        ),
      ),
    );
  }

  testWidgets('shows the keyword handed over by the host app', (tester) async {
    await pumpScreen(tester, keyword: 'flutter');

    expect(find.text('keyword: flutter'), findsOneWidget);
  });

  testWidgets('does not search until the button is pressed', (tester) async {
    final client = FakeGitHubClient();
    await pumpScreen(tester, client: client);

    expect(client.keywords, isEmpty);
    expect(find.text('ボタンを押すと検索結果が表示されます。'), findsOneWidget);
  });

  testWidgets('lists the repositories returned for the keyword', (
    tester,
  ) async {
    final client = FakeGitHubClient(results: [expoRepository, bareRepository]);
    await pumpScreen(tester, client: client);

    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();

    expect(client.keywords, ['expo']);
    expect(find.text('expo/expo'), findsOneWidget);
    expect(find.text('★ 51,842 · TypeScript'), findsOneWidget);
    // A repository with no language shows the star count on its own.
    expect(find.text('★ 0'), findsOneWidget);
  });

  testWidgets('reports the results back to the host app', (tester) async {
    await pumpScreen(
      tester,
      client: FakeGitHubClient(results: [expoRepository]),
    );

    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();

    expect(host.succeeded.single.$1, 'expo');
    expect(host.succeeded.single.$2, [expoRepository]);
    expect(host.failed, isEmpty);
  });

  testWidgets('shows the failure and reports it to the host app', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      client: FakeGitHubClient(
        error: const GitHubException('API rate limit exceeded'),
      ),
    );

    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();

    expect(find.text('API rate limit exceeded'), findsOneWidget);
    expect(host.failed.single, ('expo', 'API rate limit exceeded'));
    expect(host.succeeded, isEmpty);
  });

  testWidgets('asks the host app to close the screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('ネイティブに戻る'));

    expect(host.closeCount, 1);
  });

  testWidgets('follows a keyword the host sends while the screen is open', (
    tester,
  ) async {
    final client = FakeGitHubClient(results: [expoRepository]);
    await pumpScreen(tester, client: client);

    keywordChanges.add('swift');
    await tester.pump();
    expect(find.text('keyword: swift'), findsOneWidget);

    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();
    expect(client.keywords, ['swift']);
  });

  testWidgets('clears the previous results when the keyword is replaced', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      client: FakeGitHubClient(results: [expoRepository]),
    );
    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();

    keywordChanges.add('swift');
    // The keyword arrives on a stream event, after the frame that is pending
    // from the search; settle so both have been drawn.
    await tester.pumpAndSettle();

    expect(find.text('keyword: swift'), findsOneWidget);
    expect(find.text('expo/expo'), findsNothing);
  });

  testWidgets('marks each step of the benchmark scenario', (tester) async {
    await pumpScreen(
      tester,
      client: FakeGitHubClient(results: [expoRepository]),
    );
    expect(host.marks, [BenchMarker.embedFirstFrame]);

    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();
    keywordChanges.add('swift');
    await tester.pump();

    expect(host.marks, [
      BenchMarker.embedFirstFrame,
      BenchMarker.searchTapped,
      BenchMarker.searchRendered,
      BenchMarker.keywordApplied,
    ]);
  });

  test('groups star counts by thousands', () {
    expect(groupThousands(0), '0');
    expect(groupThousands(999), '999');
    expect(groupThousands(51842), '51,842');
    expect(groupThousands(1234567), '1,234,567');
  });

  group('RepoSearchApp', () {
    testWidgets('opens a fresh screen for every start from the host', (
      tester,
    ) async {
      final baseUrls = <String>[];
      await tester.pumpWidget(
        RepoSearchApp(
          host: host,
          createClient: (baseUrl) {
            baseUrls.add(baseUrl);
            return FakeGitHubClient(results: [expoRepository]);
          },
        ),
      );
      await tester.tap(find.text('リポジトリを検索'));
      await tester.pumpAndSettle();
      expect(find.text('expo/expo'), findsOneWidget);

      host.send(
        const StartScreen(
          keyword: 'swift',
          apiBaseUrl: 'http://127.0.0.1:8787',
        ),
      );
      await tester.pump();

      expect(find.text('keyword: swift'), findsOneWidget);
      // The previous visit's results are gone.
      expect(find.text('expo/expo'), findsNothing);
      expect(baseUrls.last, 'http://127.0.0.1:8787');
    });

    testWidgets('passes keyword commands on to the open screen', (
      tester,
    ) async {
      await tester.pumpWidget(RepoSearchApp(host: host));

      host.send(const SetKeyword('kotlin'));
      await tester.pump();

      expect(find.text('keyword: kotlin'), findsOneWidget);
    });
  });
}
