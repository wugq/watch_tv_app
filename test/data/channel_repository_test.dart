import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tv/core/checksum.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/data/sources/channel_database.dart';

const v1Schema =
    'CREATE TABLE CHANNELS(key TEXT PRIMARY KEY, name TEXT, url TEXT, category TEXT)';

Future<Database> openMemory() {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
}

void main() {
  sqfliteFfiInit();

  late Database db;
  late ChannelRepository repository;

  setUp(() async {
    db = await openMemory();
    await db.execute('PRAGMA foreign_keys = ON');
    await ChannelDatabase.create(db);
    repository = SqfliteChannelRepository(db);
  });

  tearDown(() => db.close());

  Channel channel(String name, List<String> urls, [String? category]) =>
      Channel.create(name: name, urls: urls, category: category);

  test(
    'import adds new channels and merges sources of existing ones',
    () async {
      await repository.import([
        channel('A', ['http://a/1'], 'News'),
        channel('B', ['http://b/1']),
      ]);

      final result = await repository.import([
        channel('A', ['http://a/1', 'http://a/2'], 'Live'),
        channel('C', ['http://c/1']),
      ]);

      expect(result.added, 1);
      expect(result.updated, 1);
      final all = await repository.getAll();
      expect(all.map((c) => c.name), ['A', 'B', 'C']);
      expect(all.first.urls, ['http://a/1', 'http://a/2']);
      expect(all.first.category, 'Live');
    },
  );

  test('replace keeps position and replaces all sources', () async {
    final a = channel('A', ['http://a/1', 'http://a/2']);
    await repository.import([
      a,
      channel('B', ['http://b/1']),
    ]);

    await repository.replace(a, channel('A', ['http://a/3'], 'News'));

    final all = await repository.getAll();
    expect(all.map((c) => c.name), ['A', 'B']);
    expect(all.first.urls, ['http://a/3']);
  });

  test('replace with a new name removes the old channel', () async {
    final a = channel('A', ['http://a/1']);
    await repository.import([a]);

    await repository.replace(a, channel('A2', ['http://a/1']));

    final all = await repository.getAll();
    expect(all.map((c) => c.name), ['A2']);
  });

  test('deleteAll removes the channels and their sources', () async {
    final a = channel('A', ['http://a/1', 'http://a/2']);
    final b = channel('B', ['http://b/1']);
    await repository.import([
      a,
      b,
      channel('C', ['http://c/1']),
    ]);

    await repository.deleteAll([a.key, b.key]);

    expect((await repository.getAll()).map((c) => c.name), ['C']);
    expect(await db.query(ChannelDatabase.sources), hasLength(1));
  });

  test('favorite and watch time are stored', () async {
    final a = channel('A', ['http://a/1']);
    await repository.import([a]);
    final time = DateTime(2026, 10, 8, 20, 30);

    await repository.setFavorite(a.key, true);
    await repository.markWatched(a.key, time);

    final stored = (await repository.getAll()).single;
    expect(stored.favorite, isTrue);
    expect(stored.lastWatched, time);
  });

  group('playlists', () {
    test('addPlaylist stores the list with counts', () async {
      await repository.addPlaylist(
        name: 'tv',
        url: 'https://example.com/tv.m3u',
        channels: [
          channel('A', ['http://a/1', 'http://a/2']),
          channel('B', ['http://b/1']),
        ],
      );

      final playlist = (await repository.getPlaylists()).single;
      expect(playlist.name, 'tv');
      expect(playlist.canRefresh, isTrue);
      expect(playlist.channelCount, 2);
      expect(playlist.sourceCount, 3);
    });

    test('refresh replaces its sources and keeps favorites', () async {
      await repository.addPlaylist(
        name: 'tv',
        url: 'https://example.com/tv.m3u',
        channels: [
          channel('A', ['http://a/1']),
          channel('B', ['http://b/1']),
        ],
      );
      final a = channel('A', ['http://a/1']);
      await repository.setFavorite(a.key, true);
      final id = (await repository.getPlaylists()).single.id;

      await repository.refreshPlaylist(id, [
        channel('A', ['http://a/2']),
        channel('C', ['http://c/1']),
      ]);

      final all = await repository.getAll();
      expect(all.map((c) => c.name), ['A', 'C'], reason: 'B is gone');
      expect(all.first.urls, ['http://a/2']);
      expect(all.first.favorite, isTrue);
    });

    test(
      'delete removes its channels but keeps sources from elsewhere',
      () async {
        await repository.addPlaylist(
          name: 'one',
          channels: [
            channel('A', ['http://a/1']),
            channel('B', ['http://b/1']),
          ],
        );
        await repository.addPlaylist(
          name: 'two',
          channels: [
            channel('B', ['http://b/2']),
          ],
        );
        await repository.import([
          channel('A', ['http://a/manual']),
        ]);
        final one = (await repository.getPlaylists()).first;

        await repository.deletePlaylist(one.id);

        final all = await repository.getAll();
        expect(all.map((c) => c.name), ['A', 'B']);
        expect(all[0].urls, ['http://a/manual']);
        expect(all[1].urls, ['http://b/2']);
        expect(await repository.getPlaylists(), hasLength(1));
      },
    );
  });

  group('migration', () {
    test('v1 to v3 keeps channels, order and URLs', () async {
      final v1 = await openMemory();
      await v1.execute(v1Schema);
      for (final name in ['Z', 'A', 'M']) {
        await v1.insert('CHANNELS', {
          'key': sha1Of(name),
          'name': name,
          'url': 'http://x/$name',
          'category': 'default',
        });
      }

      await v1.transaction((txn) => ChannelDatabase.upgrade(txn, 1, 3));

      final all = await SqfliteChannelRepository(v1).getAll();
      expect(all.map((c) => c.name), ['Z', 'A', 'M']);
      expect(all.first.urls, ['http://x/Z']);
      expect(all.first.key, sha1Of('Z'));
      expect(all.first.favorite, isFalse);
      await v1.close();
    });

    test('v2 to v3 keeps sources as added by hand', () async {
      final v2 = await openMemory();
      await v2.execute(v1Schema);
      await v2.transaction((txn) => ChannelDatabase.migrateV1ToV2(txn));
      await v2.insert('CHANNELS', {
        'key': 'k',
        'name': 'A',
        'category': 'News',
      });
      await v2.insert('SOURCES', {
        'channel_key': 'k',
        'position': 0,
        'url': 'http://a/1',
      });

      await v2.transaction((txn) => ChannelDatabase.upgrade(txn, 2, 3));

      final repo = SqfliteChannelRepository(v2);
      expect((await repo.getAll()).single.urls, ['http://a/1']);
      expect(await repo.getPlaylists(), isEmpty);
      await v2.close();
    });
  });
}
