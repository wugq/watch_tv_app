import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tv/app/routes.dart';
import 'package:tv/app/theme.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/data/sources/playlist_loader.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/widgets/mobile_browser.dart';
import 'package:tv/features/home/widgets/navigation_menu.dart';
import 'package:tv/features/player/player_controller.dart';

import '../helpers/fakes.dart';

const playlist =
    '#EXTM3U\n'
    '#EXTINF:-1 group-title="News",Alpha\n'
    'http://x/a1\n'
    '#EXTINF:-1 group-title="News",Alpha\n'
    'http://x/a2\n'
    '#EXTINF:-1 group-title="Sport",Beta\n'
    'http://x/b\n';

const phone = Size(390, 844);
const desktop = Size(1280, 800);

Future<FakePlayerController> pumpApp(
  WidgetTester tester,
  List<Channel> channels, {
  Size size = phone,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  Get.testMode = true;
  Get.put<ChannelRepository>(InMemoryChannelRepository(channels));
  Get.put(
    PlaylistLoader(
      client: MockClient((request) async {
        if (request.url.path == '/tv.m3u') {
          return http.Response.bytes(utf8.encode(playlist), 200);
        }
        return http.Response('not found', 404);
      }),
    ),
  );
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

/// Lets snackbars time out so no timer is left at the end of a test.
Future<void> settleSnackbars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

final alpha = Channel.create(
  name: 'Alpha',
  urls: ['http://x/a'],
  category: 'News',
);
final beta = Channel.create(
  name: 'Beta',
  urls: ['http://x/b'],
  category: 'Sport',
);

/// Text in the channel list (not the now playing bar or the player).
Finder inList(String text) =>
    find.descendant(of: find.byType(MobileBrowser), matching: find.text(text));

/// Text in the desktop menu.
Finder inMenu(String text) =>
    find.descendant(of: find.byType(NavigationMenu), matching: find.text(text));

void main() {
  tearDown(Get.reset);

  group('phone', () {
    testWidgets('shows the empty state without channels', (tester) async {
      await pumpApp(tester, const []);

      expect(find.text('No channels yet'), findsOneWidget);
      expect(find.text('Add playlist'), findsOneWidget);
    });

    testWidgets('plays the first channel and switches on tap', (tester) async {
      final player = await pumpApp(tester, [alpha, beta]);

      expect(player.played.map((c) => c.name), ['Alpha']);

      await tester.tap(find.text('Beta'));
      await tester.pump();

      expect(player.channel.value?.name, 'Beta');
    });

    testWidgets('a starred channel shows up in Favorites', (tester) async {
      await pumpApp(tester, [alpha, beta]);

      await tester.tap(find.byTooltip('Add to favorites').at(2));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Favorites'));
      await tester.pumpAndSettle();

      expect(inList('Beta'), findsOneWidget);
      expect(inList('Alpha'), findsNothing);
    });

    testWidgets('category chips filter the list', (tester) async {
      await pumpApp(tester, [alpha, beta]);

      // Chips past the screen edge are reached by scrolling; every section
      // is also in the sheet behind the grid button.
      await tester.tap(find.byTooltip('All categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'News'));
      await tester.pumpAndSettle();
      expect(inList('Alpha'), findsOneWidget);
      expect(inList('Beta'), findsNothing);

      await tester.tap(find.byTooltip('All categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Sport'));
      await tester.pumpAndSettle();

      expect(inList('Beta'), findsOneWidget);
      expect(inList('Alpha'), findsNothing);
    });

    testWidgets('search finds channels by name', (tester) async {
      await pumpApp(tester, [alpha, beta]);

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bet');
      await tester.pump();

      expect(inList('Beta'), findsOneWidget);
      expect(inList('Alpha'), findsNothing);
    });

    testWidgets('imports an M3U playlist from a URL', (tester) async {
      await pumpApp(tester, const []);

      await tester.tap(find.text('Add playlist'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Playlist URL'),
        'https://example.com/missing.m3u',
      );
      await tester.tap(find.byTooltip('Download'));
      await tester.pumpAndSettle();
      expect(find.text('Download failed: HTTP 404'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Playlist URL'),
        'https://example.com/tv.m3u',
      );
      await tester.tap(find.byTooltip('Download'));
      await tester.pumpAndSettle();
      expect(find.text('2 channels'), findsOneWidget);
      expect(find.text('3 sources'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'tv'),
        findsOneWidget,
        reason: 'name from the URL',
      );

      await tester.ensureVisible(find.text('Add 2 channels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 2 channels'));
      await tester.pumpAndSettle();

      expect(find.text('News · 2 sources'), findsOneWidget);
      expect(find.text('No channels yet'), findsNothing);
      await settleSnackbars(tester);
    });

    testWidgets('adds a single channel', (tester) async {
      await pumpApp(tester, const []);

      await tester.tap(find.text('Add a single channel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter a channel name'), findsOneWidget);
      expect(find.text('Add at least one stream URL'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Channel name'),
        'Gamma',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Add a stream URL'),
        'https://example.com/g.m3u8',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Gamma'), findsWidgets);
      expect(find.text('No channels yet'), findsNothing);
      await settleSnackbars(tester);
    });

    testWidgets('edits sources and deletes a channel', (tester) async {
      final player = await pumpApp(tester, [alpha, beta]);

      await tester.longPress(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(find.text('Edit channel'), findsOneWidget);
      expect(find.text('http://x/b'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete channel'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsNothing);
      expect(player.channel.value?.name, 'Alpha');
      await settleSnackbars(tester);
    });

    testWidgets('library page deletes selected channels', (tester) async {
      await pumpApp(tester, [alpha, beta]);

      await tester.tap(find.byTooltip('Manage library'));
      await tester.pumpAndSettle();
      expect(find.text('No playlists'), findsOneWidget);

      await tester.tap(find.text('Channels'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Alpha'));
      await tester.pump();
      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete selected'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('No channels'), findsOneWidget);
      await settleSnackbars(tester);
    });
  });

  group('library and visibility', () {
    testWidgets('hiding a category in the library hides it on home', (
      tester,
    ) async {
      await pumpApp(tester, [alpha, beta]);

      await tester.tap(find.byTooltip('Manage library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2 shown'), findsOneWidget);

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 shown'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      // The selected section is still All channels.
      expect(inList('Alpha'), findsOneWidget);
      expect(inList('Beta'), findsNothing);
    });

    testWidgets('hide and add to category from the channel menu', (
      tester,
    ) async {
      await pumpApp(tester, [alpha, beta]);

      await tester.tap(find.byTooltip('More').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to category…'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'New category'),
        'Mine',
      );
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await settleSnackbars(tester);

      await tester.tap(find.byTooltip('All categories'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Mine'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Mine'));
      await tester.pumpAndSettle();
      expect(inList('Beta'), findsOneWidget);

      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();

      expect(inList('Beta'), findsNothing);
      expect(find.text('Undo'), findsOneWidget);
      await settleSnackbars(tester);
    });

    testWidgets('a User-Agent can be set for a source', (tester) async {
      await pumpApp(tester, [alpha]);

      await tester.longPress(inList('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit source'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'User-Agent (optional)'),
        'MyAgent/1.0',
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('User-Agent: MyAgent/1.0'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await Get.find<ChannelRepository>().getAll();
      expect(saved.single.sources.single.userAgent, 'MyAgent/1.0');
    });
  });

  group('desktop', () {
    testWidgets('pointing at a category opens its channels', (tester) async {
      final player = await pumpApp(tester, [alpha, beta], size: desktop);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(900, 400));
      addTearDown(mouse.removePointer);

      expect(find.text('Beta'), findsNothing, reason: 'panel closed');

      await mouse.moveTo(tester.getCenter(inMenu('Sport').first));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(player.channel.value?.name, 'Beta');

      // Leaving the menu closes the panel.
      await mouse.moveTo(tester.getCenter(inMenu('Sport').first));
      await tester.pump(const Duration(milliseconds: 200));
      await mouse.moveTo(const Offset(900, 400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(inMenu('Beta'), findsNothing);
    });

    testWidgets('clicking a section keeps its panel open', (tester) async {
      await pumpApp(tester, [alpha, beta], size: desktop);

      await tester.tap(find.text('All channels'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Alpha'), findsWidgets);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('keyboard switches channels and full screen', (tester) async {
      final player = await pumpApp(tester, [alpha, beta], size: desktop);
      final controller = Get.find<HomeController>();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(player.channel.value?.name, 'Beta');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(player.channel.value?.name, 'Alpha', reason: 'wraps around');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(controller.isFullscreen.value, isTrue);

      // The menu button opens the channel menu over the video.
      await tester.tap(find.byTooltip('Channels'));
      await tester.pumpAndSettle();
      expect(find.text('All channels'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.isFullscreen.value, isFalse);
    });

    testWidgets('typing in search does not trigger shortcuts', (tester) async {
      final player = await pumpApp(tester, [alpha, beta], size: desktop);

      await tester.enterText(find.byType(TextField).first, 'f');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();

      expect(Get.find<HomeController>().isFullscreen.value, isFalse);
      expect(player.status.value, PlaybackStatus.playing);
      expect(find.text('Results for "f"'), findsOneWidget);
    });
  });
}
