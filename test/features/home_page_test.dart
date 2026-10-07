import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tv/app/routes.dart';
import 'package:tv/app/theme.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/player/player_controller.dart';

import '../helpers/fakes.dart';

Future<FakePlayerController> pumpApp(
  WidgetTester tester,
  List<Channel> channels,
) async {
  Get.testMode = true;
  Get.put<ChannelRepository>(InMemoryChannelRepository(channels));
  final player = FakePlayerController();
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.dark(),
      initialRoute: Routes.home,
      getPages: [
        appPages.first.copy(
          binding: BindingsBuilder(() {
            Get.put<PlayerController>(player);
            Get.put(HomeController(Get.find(), player));
          }),
        ),
        ...appPages.skip(1),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return player;
}

void main() {
  tearDown(Get.reset);

  testWidgets('shows empty state without channels', (tester) async {
    await pumpApp(tester, const []);

    expect(find.text('No channels yet'), findsOneWidget);
    expect(find.text('Add channels'), findsOneWidget);
  });

  testWidgets('plays the first channel and switches on tap', (tester) async {
    final a = Channel.create(name: 'Alpha', url: 'http://x/a');
    final b = Channel.create(name: 'Beta', url: 'http://x/b');
    final player = await pumpApp(tester, [a, b]);

    expect(player.played, [a]);

    await tester.tap(find.text('Beta'));
    await tester.pump();

    expect(player.played, [a, b]);
  });

  testWidgets('adds a channel from the editor', (tester) async {
    await pumpApp(tester, const []);

    await tester.tap(find.text('Add channels'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a channel name'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Channel name'),
      'Gamma',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Stream URL'),
      'https://example.com/g.m3u8',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Gamma'), findsWidgets);
    expect(find.text('No channels yet'), findsNothing);
    expect(find.text('1 channel saved'), findsOneWidget);

    // Let the snackbar close.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
