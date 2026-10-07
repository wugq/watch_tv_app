import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/player/player_controller.dart';
import 'package:tv/features/player/widgets/player_view.dart';

import 'player_controller_test.dart' show FakeVideoController;

void main() {
  testWidgets('shows the video once the stream is initialized', (tester) async {
    final player = PlayerController(
      createVideoController: (uri) => FakeVideoController(uri, fails: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerView(
          controller: player,
          isFullscreen: false,
          onToggleFullscreen: () {},
        ),
      ),
    );
    expect(find.byType(VideoPlayer), findsNothing);

    await tester.runAsync(
      () => player.play(Channel.create(name: 'A', urls: ['http://good/1'])),
    );
    await tester.pump();

    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('keeps the video after a non-fatal error (media_kit)', (
    tester,
  ) async {
    final controllers = <FakeVideoController>[];
    final player = PlayerController(
      errorsAreFatal: false,
      createVideoController: (uri) {
        final controller = FakeVideoController(uri, fails: false);
        controllers.add(controller);
        return controller;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerView(
          controller: player,
          isFullscreen: false,
          onToggleFullscreen: () {},
        ),
      ),
    );
    await tester.runAsync(
      () => player.play(Channel.create(name: 'A', urls: ['http://good/1'])),
    );
    await tester.pump();

    controllers.single
      ..fail()
      ..keepPlaying();
    await tester.pump();

    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(player.aspectRatio.value, 16 / 9);
    expect(player.status.value, PlaybackStatus.playing);

    player.togglePlay();
    await tester.pump();
    expect(controllers, hasLength(1), reason: 'pauses, does not reopen');
    expect(controllers.single.value.isPlaying, isFalse);

    await tester.pump(const Duration(seconds: 4));
  });
}
