import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repo_search/src/github_client.dart';
import 'package:repo_search/src/host_channel.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(HostChannel.channelName);
  late List<MethodCall> sent;

  setUp(() {
    sent = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          sent.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('decodeCommand', () {
    test('reads start with the keyword and the base url', () {
      final command = HostChannel.decodeCommand(
        const MethodCall('start', {
          'keyword': 'swift',
          'apiBaseUrl': 'http://127.0.0.1:8787',
        }),
      );

      expect(command, isA<StartScreen>());
      command as StartScreen;
      expect(command.keyword, 'swift');
      expect(command.apiBaseUrl, 'http://127.0.0.1:8787');
    });

    test('falls back to the real API when no base url is given', () {
      final command = HostChannel.decodeCommand(
        const MethodCall('start', {'keyword': 'swift', 'apiBaseUrl': ''}),
      ) as StartScreen;

      expect(command.apiBaseUrl, GitHubClient.defaultBaseUrl);
    });

    test('reads setKeyword', () {
      final command = HostChannel.decodeCommand(
        const MethodCall('setKeyword', {'keyword': 'kotlin'}),
      );

      expect(command, isA<SetKeyword>());
      expect((command as SetKeyword).keyword, 'kotlin');
    });

    test('ignores anything else', () {
      expect(HostChannel.decodeCommand(const MethodCall('start')), isNull);
      expect(
        HostChannel.decodeCommand(const MethodCall('start', {'keyword': ''})),
        isNull,
      );
      expect(
        HostChannel.decodeCommand(
          const MethodCall('somethingElse', {'keyword': 'expo'}),
        ),
        isNull,
      );
    });
  });

  test('reports results with only the fields the host consumes', () async {
    HostChannel().notifySearchSucceeded('expo', [
      expoRepository,
      bareRepository,
    ]);
    await pumpEventQueue();

    expect(sent.single.method, 'searchSucceeded');
    expect(sent.single.arguments, {
      'keyword': 'expo',
      'repositories': [
        {
          'id': 65750241,
          'fullName': 'expo/expo',
          'stars': 51842,
          'language': 'TypeScript',
        },
        {'id': 1, 'fullName': 'a/b', 'stars': 0, 'language': null},
      ],
    });
  });

  test('reports a failure', () async {
    HostChannel().notifySearchFailed('expo', 'API rate limit exceeded');
    await pumpEventQueue();

    expect(sent.single.method, 'searchFailed');
    expect(sent.single.arguments, {
      'keyword': 'expo',
      'message': 'API rate limit exceeded',
    });
  });

  test('asks the host to close the screen', () async {
    HostChannel().close();
    await pumpEventQueue();

    expect(sent.single.method, 'close');
  });

  test('sends a marker with the time it was taken', () async {
    final before = DateTime.now().millisecondsSinceEpoch;

    HostChannel().mark(BenchMarker.searchTapped);
    await pumpEventQueue();

    final arguments = sent.single.arguments as Map;
    expect(sent.single.method, 'mark');
    expect(arguments['name'], 'searchTapped');
    expect(arguments['epochMs'], greaterThanOrEqualTo(before));
  });

  test('delivers the host commands to the listener', () async {
    final commands = <HostCommand>[];
    HostChannel().listen(commands.add);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          HostChannel.channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('setKeyword', {'keyword': 'kotlin'}),
          ),
          (_) {},
        );

    expect((commands.single as SetKeyword).keyword, 'kotlin');
  });
}
