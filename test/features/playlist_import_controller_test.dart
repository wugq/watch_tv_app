import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/data/sources/playlist_loader.dart';
import 'package:tv/features/playlist_import/playlist_import_controller.dart';

import '../helpers/fakes.dart';

class _FailingRepository extends InMemoryChannelRepository {
  @override
  Future<ImportResult> addPlaylist({
    required String name,
    String? url,
    required Iterable<Channel> channels,
  }) async {
    throw StateError('disk full');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('a save error is shown and the preview stays', () async {
    Get.testMode = true;
    final controller = PlaylistImportController(
      _FailingRepository(),
      PlaylistLoader(),
    );
    controller.pasteText.text = 'A,http://example.com/a.m3u8';
    await controller.parseText();
    expect(controller.preview.value?.channels, hasLength(1));

    await controller.save();

    expect(controller.saveError.value, contains('disk full'));
    expect(controller.preview.value, isNotNull);
    expect(controller.isSaving.value, isFalse);
  });

  test('suggestName uses the file name of a URL', () {
    expect(
      PlaylistImportController.suggestName(
        'https://iptv-org.github.io/iptv/index.m3u',
      ),
      'index',
    );
    expect(PlaylistImportController.suggestName('my list.m3u'), 'my list');
  });
}
