import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/home_controller.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final news = Channel.create(
    name: 'A',
    urls: ['http://x/a'],
    category: 'News',
  );
  final sport = Channel.create(
    name: 'B',
    urls: ['http://x/b'],
    category: 'Sport',
  );

  late FakePlayerController player;
  late HomeController controller;

  setUp(() async {
    Get.testMode = true;
    player = Get.put(FakePlayerController());
    controller = Get.put(
      HomeController(InMemoryChannelRepository([news, sport]), player),
    );
    await controller.reload();
  });

  tearDown(Get.reset);

  test('lists categories in order of first use', () {
    expect(controller.categories, ['News', 'Sport']);
  });

  test('filters by selected category', () {
    controller.selectCategory('Sport');

    expect(controller.visibleChannels, [sport]);
  });

  test('deleting the last channel of a category resets the filter', () async {
    controller.selectCategory('Sport');

    await controller.deleteChannel(sport);

    expect(controller.selectedCategory.value, HomeController.allCategories);
    expect(controller.channels, [news]);
  });

  test('deleting the playing channel stops playback', () async {
    controller.play(news);

    await controller.deleteChannel(news);

    expect(player.channel.value, isNull);
  });

  test('playAdjacent follows the visible list and wraps', () {
    controller.playAdjacent(1);
    expect(player.channel.value, news, reason: 'nothing playing: first');

    controller.playAdjacent(1);
    expect(player.channel.value, sport);

    controller.selectCategory('News');
    controller.playAdjacent(-1);
    expect(player.channel.value, news);
  });
}
