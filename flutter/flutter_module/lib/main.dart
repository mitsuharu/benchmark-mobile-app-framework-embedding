import 'dart:async';

import 'package:flutter/material.dart';

import 'src/github_client.dart';
import 'src/host_channel.dart';
import 'src/repo_search_screen.dart';

/// The entrypoint the host app's cached engine runs once, at launch.
void main() => runApp(RepoSearchApp(host: HostChannel()));

/// Shows the search screen for whatever the host app last asked for.
///
/// The engine, and this app with it, outlive every visit to the screen, so
/// each `start` from the host builds a new screen with a new key — the
/// equivalent of React Native creating a new root view with fresh
/// `initialProps`.
class RepoSearchApp extends StatefulWidget {
  const RepoSearchApp({super.key, required this.host, this.createClient});

  final HostChannel host;

  /// Makes the API client for a visit. Tests replace it.
  final GitHubClient Function(String apiBaseUrl)? createClient;

  @override
  State<RepoSearchApp> createState() => _RepoSearchAppState();
}

class _RepoSearchAppState extends State<RepoSearchApp> {
  final _keywordChanges = StreamController<String>.broadcast();

  // Shows a screen straight away so `flutter run` on the module works; the
  // host app's first `start` replaces it.
  StartScreen _visit = const StartScreen(
    keyword: 'expo',
    apiBaseUrl: GitHubClient.defaultBaseUrl,
  );
  int _visitCount = 0;

  @override
  void initState() {
    super.initState();
    widget.host.listen((command) {
      switch (command) {
        case StartScreen():
          setState(() {
            _visit = command;
            _visitCount++;
          });
        case SetKeyword(:final keyword):
          _keywordChanges.add(keyword);
      }
    });
  }

  @override
  void dispose() {
    _keywordChanges.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createClient =
        widget.createClient ?? (baseUrl) => GitHubClient(baseUrl: baseUrl);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepoSearchScreen(
        key: ValueKey(_visitCount),
        initialKeyword: _visit.keyword,
        client: createClient(_visit.apiBaseUrl),
        host: widget.host,
        keywordChanges: _keywordChanges.stream,
      ),
    );
  }
}
