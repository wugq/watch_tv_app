import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/library_section.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final news = Channel.create(
    name: 'CCTV News',
    urls: ['http://x/a'],
    category: 'News',
  );
  final sport = Channel.create(
    name: 'Sport 1',
    urls: ['http://x/b'],
    category: 'Sport',
  );
  final movie = Channel(
    key: 'm',
    name: 'Movies',
    category: 'Film',
    urls: const ['http://x/m'],
    favorite: true,
    lastWatched: DateTime(2026, 1, 1),
  );

  late FakePlayerController player;
  late InMemoryChannelRepository repository;
  late HomeController controller;

  setUp(() async {
    Get.testMode = true;
    player = Get.put(FakePlayerController());
    repository = InMemoryChannelRepository([news, sport, movie]);
    controller = Get.put(HomeController(repository, player));
    await controller.reload();
  });

  tearDown(Get.reset);

  test('sections: fixed ones, then categories in order of first use', () {
    expect(controller.sections, [
      LibrarySection.favorites,
      LibrarySection.recent,
      LibrarySection.all,
      const LibrarySection.category('News'),
      const LibrarySection.category('Sport'),
      const LibrarySection.category('Film'),
    ]);
  });

  test('channelsIn returns the channels of a section', () {
    expect(controller.channelsIn(LibrarySection.favorites), [movie]);
    expect(controller.channelsIn(LibrarySection.recent), [movie]);
    expect(controller.channelsIn(const LibrarySection.category('Sport')), [
      sport,
    ]);
  });

  test('search matches name and category, ignoring case', () {
    expect(controller.search('cctv'), [news]);
    expect(controller.search('SPORT'), [sport]);
    expect(controller.search('  '), isEmpty);
  });

  test('a query replaces the section in visibleChannels', () {
    controller.selectSection(const LibrarySection.category('Film'));
    controller.setQuery('sport');

    expect(controller.visibleChannels, [sport]);

    controller.selectSection(LibrarySection.all);
    expect(controller.query.value, isEmpty, reason: 'selecting clears it');
  });

  test('toggleFavorite updates the list and the repository', () async {
    await controller.toggleFavorite(news);

    expect(
      controller.channelsIn(LibrarySection.favorites),
      [
        news,
        movie,
      ].map((c) => c.key == news.key ? c.copyWith(favorite: true) : c),
    );
    expect((await repository.getAll()).first.favorite, isTrue);
  });

  test('play records the watch time; recent is newest first', () async {
    controller.play(sport);

    final recent = controller.channelsIn(LibrarySection.recent);
    expect(recent.map((c) => c.name), ['Sport 1', 'Movies']);
    expect((await repository.getAll())[1].lastWatched, isNotNull);
  });

  test('deleting the last channel of a category resets the section', () async {
    controller.selectSection(const LibrarySection.category('Sport'));

    await controller.deleteChannel(sport);

    expect(controller.section.value, LibrarySection.all);
    expect(controller.channels.map((c) => c.name), ['CCTV News', 'Movies']);
  });

  test('deleting the playing channel stops playback', () async {
    controller.play(news);

    await controller.deleteChannel(news);

    expect(player.channel.value, isNull);
  });

  test('playAdjacent follows the visible list and wraps', () {
    controller.selectSection(LibrarySection.all);
    controller.playAdjacent(1);
    expect(player.channel.value?.key, news.key, reason: 'first when idle');

    controller.playAdjacent(1);
    expect(player.channel.value?.key, sport.key);

    controller.playAdjacent(-1);
    expect(player.channel.value?.key, news.key);

    controller.playAdjacent(-1);
    expect(player.channel.value?.key, movie.key, reason: 'wraps');
  });
}
