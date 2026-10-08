import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/player/player_controller.dart';

/// Video controller that opens or fails without a platform player.
class FakeVideoController extends VideoPlayerController {
  final bool fails;

  FakeVideoController(super.url, {required this.fails}) : super.networkUrl();

  @override
  Future<void> initialize() async {
    if (fails) {
      throw Exception('cannot open');
    }
    value = value.copyWith(
      isInitialized: true,
      size: const Size(1920, 1080),
      duration: Duration.zero,
    );
  }

  @override
  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
  }

  /// Same as video_player on an error event: the whole value is replaced.
  void fail() {
    value = VideoPlayerValue.erroneous('stream ended');
  }

  /// media_kit keeps sending state updates after a non-fatal error.
  void keepPlaying() {
    value = value.copyWith(isPlaying: true);
  }

  void buffer() {
    value = value.copyWith(isBuffering: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final channel = Channel.create(
    name: 'A',
    urls: ['http://bad/1', 'http://good/2', 'http://good/3'],
  );

  late List<String> opened;
  late List<FakeVideoController> controllers;
  late PlayerController player;

  PlayerController createPlayer({bool errorsAreFatal = true}) {
    return PlayerController(
      errorsAreFatal: errorsAreFatal,
      stallTimeout: const Duration(milliseconds: 50),
      createVideoController: (uri) {
        opened.add(uri.toString());
        final controller = FakeVideoController(uri, fails: uri.host == 'bad');
        controllers.add(controller);
        return controller;
      },
    );
  }

  setUp(() {
    opened = [];
    controllers = [];
    player = createPlayer();
  });

  test('falls back to the next source when a source fails', () async {
    await player.play(channel);
    await pumpEventQueue();

    expect(opened, ['http://bad/1', 'http://good/2']);
    expect(player.sourceIndex.value, 1);
    expect(player.status.value, PlaybackStatus.playing);
  });

  test('shows an error after every source failed once', () async {
    final allBad = Channel.create(
      name: 'B',
      urls: ['http://bad/1', 'http://bad/2'],
    );

    await player.play(allBad, source: 1);
    await pumpEventQueue();

    expect(opened, ['http://bad/2', 'http://bad/1']);
    expect(player.status.value, PlaybackStatus.error);
    expect(player.errorMessage.value, contains('all 2 sources failed'));
  });

  test('nextSource switches to the following source', () async {
    await player.play(channel, source: 1);
    await pumpEventQueue();

    await player.nextSource();
    await pumpEventQueue();

    expect(player.sourceIndex.value, 2);
    expect(opened.last, 'http://good/3');
  });

  test('a playback error moves to the next source', () async {
    await player.play(channel, source: 1);
    await pumpEventQueue();

    controllers.last.fail();
    await pumpEventQueue();

    expect(player.sourceIndex.value, 2);
    expect(player.status.value, PlaybackStatus.playing);
  });

  test('with non-fatal errors, an error keeps the source', () async {
    player = createPlayer(errorsAreFatal: false);
    await player.play(channel, source: 1);
    await pumpEventQueue();

    controllers.last.fail();
    await pumpEventQueue();

    expect(player.sourceIndex.value, 1);
    expect(opened, ['http://good/2']);
  });

  test('buffering longer than stallTimeout moves to the next source', () async {
    player = createPlayer(errorsAreFatal: false);
    await player.play(channel, source: 1);
    await pumpEventQueue();

    controllers.last.buffer();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await pumpEventQueue();

    expect(player.sourceIndex.value, 2);
    expect(opened.last, 'http://good/3');
  });

  group('app lifecycle', () {
    test('pauses when the app becomes inactive on mobile', () async {
      await player.play(channel, source: 1);
      await pumpEventQueue();

      player.didChangeAppLifecycleState(AppLifecycleState.inactive);

      expect(controllers.last.value.isPlaying, isFalse);
    });

    test('keeps playing on desktop (focus loss, full screen)', () async {
      player = PlayerController(
        pauseInBackground: false,
        createVideoController: (uri) {
          final controller = FakeVideoController(uri, fails: false);
          controllers.add(controller);
          return controller;
        },
      );
      await player.play(channel, source: 1);
      await pumpEventQueue();

      player.didChangeAppLifecycleState(AppLifecycleState.inactive);
      player.didChangeAppLifecycleState(AppLifecycleState.hidden);

      expect(controllers.last.value.isPlaying, isTrue);
    });
  });
}
