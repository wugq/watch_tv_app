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

  group('visibility', () {
    test('hidden channels are not shown anywhere', () async {
      await repository.setHidden([movie.key], true);
      await controller.reload();

      expect(controller.channelsIn(LibrarySection.all), isNot(contains(movie)));
      expect(controller.channelsIn(LibrarySection.favorites), isEmpty);
      expect(controller.search('movies'), isEmpty);
      expect(controller.categories, isNot(contains('Film')));
    });

    test('a hidden category drops out of browsing but not favorites', () async {
      await repository.setCategoryHidden(['Film', 'News'], true);
      await controller.reload();

      expect(controller.categories, ['Sport']);
      expect(controller.channelsIn(LibrarySection.all).map((c) => c.name), [
        'Sport 1',
      ]);
      expect(
        controller.channelsIn(LibrarySection.favorites).single.name,
        'Movies',
      );
    });

    test('hideChannel hides at once', () async {
      await controller.hideChannel(sport);

      expect(controller.channelsIn(LibrarySection.all).map((c) => c.name), [
        'CCTV News',
        'Movies',
      ]);
      expect((await repository.getAll())[1].hidden, isTrue);
    });
  });

  test('custom categories are sections with the chosen channels', () async {
    await controller.addToCustomCategory(sport, newName: 'Mine');
    final id = controller.customCategories.single.id;
    await controller.addToCustomCategory(news, id: id);

    final section = LibrarySection.custom(id, 'Mine');
    expect(controller.sections.indexOf(section), 3, reason: 'after fixed');
    expect(controller.channelsIn(section).map((c) => c.name), [
      'Sport 1',
      'CCTV News',
    ]);

    await controller.removeFromCustomCategory(sport, id);
    expect(controller.channelsIn(section).map((c) => c.name), ['CCTV News']);
  });

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

  test('a channel with several categories is in each of them', () async {
    await repository.import([
      Channel.create(
        name: 'Kids Music',
        urls: ['http://x/k'],
        category: 'Kids;Music',
      ),
    ]);
    await controller.reload();

    expect(controller.categories, containsAll(['Kids', 'Music']));
    expect(
      controller.channelsIn(const LibrarySection.category('Music')).single.name,
      'Kids Music',
    );
    expect(
      controller.channelsIn(const LibrarySection.category('Kids')).single.name,
      'Kids Music',
    );
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
