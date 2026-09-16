import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'github_client.dart';

/// The markers the screen reports for the benchmark (see AGENTS.md).
enum BenchMarker {
  embedFirstFrame,
  searchTapped,
  searchRendered,
  keywordApplied,
}

/// What the native host app asks the Dart side to do.
sealed class HostCommand {
  const HostCommand();
}

/// Opens the screen afresh for a keyword. The engine is started once and
/// reused, so this plays the part React Native's `initialProps` plays.
class StartScreen extends HostCommand {
  const StartScreen({required this.keyword, required this.apiBaseUrl});

  final String keyword;
  final String apiBaseUrl;
}

/// Replaces the keyword on the screen that is open.
class SetKeyword extends HostCommand {
  const SetKeyword(this.keyword);

  final String keyword;
}

/// The method channel between this screen and the native host app. It carries
/// traffic in both directions: commands in, results out.
///
/// Its native end is `FlutterRepoSearch` in each host app.
class HostChannel {
  HostChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'repo_search';

  final MethodChannel _channel;

  /// Listens for the host app's commands.
  void listen(void Function(HostCommand command) onCommand) {
    _channel.setMethodCallHandler((call) async {
      final command = decodeCommand(call);
      if (command != null) {
        onCommand(command);
      }
      return null;
    });
  }

  /// One call from the host as a command, or null when it is not one.
  static HostCommand? decodeCommand(MethodCall call) {
    final arguments = call.arguments;
    if (arguments is! Map) {
      return null;
    }
    final keyword = arguments['keyword'];
    if (keyword is! String || keyword.isEmpty) {
      return null;
    }
    switch (call.method) {
      case 'start':
        final apiBaseUrl = arguments['apiBaseUrl'];
        return StartScreen(
          keyword: keyword,
          apiBaseUrl: apiBaseUrl is String && apiBaseUrl.isNotEmpty
              ? apiBaseUrl
              : GitHubClient.defaultBaseUrl,
        );
      case 'setKeyword':
        return SetKeyword(keyword);
      default:
        return null;
    }
  }

  void notifySearchSucceeded(String keyword, List<Repository> repositories) {
    _send('searchSucceeded', {
      'keyword': keyword,
      // Only the fields the host consumes.
      'repositories': [
        for (final repository in repositories)
          {
            'id': repository.id,
            'fullName': repository.fullName,
            'stars': repository.stars,
            'language': repository.language,
          },
      ],
    });
  }

  void notifySearchFailed(String keyword, String message) {
    _send('searchFailed', {'keyword': keyword, 'message': message});
  }

  /// Asks the host app to close the screen.
  void close() => _send('close');

  /// Reports a benchmark marker. The time is taken here, on the Dart side,
  /// and the host writes it to the native log.
  void mark(BenchMarker marker) {
    _send('mark', {
      'name': marker.name,
      'epochMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Reports a marker at the frame boundary after the change has been drawn:
  /// the frame being built draws it, and the next one means it is on screen.
  /// Every implementation waits for the same two frame boundaries (see
  /// AGENTS.md).
  void markAfterFrame(BenchMarker marker) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) => mark(marker));
      SchedulerBinding.instance.scheduleFrame();
    });
  }

  void _send(String method, [Object? arguments]) {
    // Nothing on the native side answers with a value, and the calls are
    // fire-and-forget like React Native's sendMessage.
    unawaited(_channel.invokeMethod<void>(method, arguments));
  }
}
