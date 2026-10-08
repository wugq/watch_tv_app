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

  test('stores HTTP headers of sources', () async {
    await repository.import([
      Channel.create(
        name: 'A',
        sources: [
          StreamSource('http://a/1', userAgent: 'UA', referrer: 'https://r/'),
          StreamSource('http://a/2'),
        ],
      ),
    ]);

    final sources = (await repository.getAll()).single.sources;
    expect(sources.first.headers, {
      'User-Agent': 'UA',
      'Referer': 'https://r/',
    });
    expect(sources.last.hasHeaders, isFalse);
  });

  test('hidden channels and categories are stored', () async {
    final a = channel('A', ['http://a/1'], 'News');
    await repository.import([
      a,
      channel('B', ['http://b/1']),
    ]);

    await repository.setHidden([a.key], true);
    await repository.setCategoryHidden(['News', 'Shop'], true);
    await repository.setCategoryHidden(['Shop'], false);

    final all = await repository.getAll();
    expect(all.first.hidden, isTrue);
    expect(all.last.hidden, isFalse);
    expect(await repository.getHiddenCategories(), {'News'});
  });

  group('custom categories', () {
    test('create, add in order, remove, rename, delete', () async {
      final a = channel('A', ['http://a/1']);
      final b = channel('B', ['http://b/1']);
      await repository.import([a, b]);

      final kids = await repository.createCustomCategory('Kids');
      final news = await repository.createCustomCategory('News');
      await repository.addToCustomCategory(kids, [b.key, a.key]);
      await repository.addToCustomCategory(kids, [b.key]);
      await repository.renameCustomCategory(news, 'My news');

      var custom = await repository.getCustomCategories();
      expect(custom.map((c) => c.name), ['Kids', 'My news']);
      expect(custom.first.channelKeys, [b.key, a.key]);

      await repository.removeFromCustomCategory(kids, [b.key]);
      await repository.deleteCustomCategory(news);
      custom = await repository.getCustomCategories();
      expect(custom.single.channelKeys, [a.key]);
    });

    test('rename keeps membership, delete removes it', () async {
      final a = channel('A', ['http://a/1']);
      await repository.import([a]);
      final id = await repository.createCustomCategory('Mine');
      await repository.addToCustomCategory(id, [a.key]);

      final renamed = channel('A2', ['http://a/1']);
      await repository.replace(a, renamed);
      expect((await repository.getCustomCategories()).single.channelKeys, [
        renamed.key,
      ]);

      await repository.delete(renamed.key);
      expect(
        (await repository.getCustomCategories()).single.channelKeys,
        isEmpty,
      );
    });

    test('deleting a playlist cleans up membership', () async {
      await repository.addPlaylist(
        name: 'p',
        channels: [
          channel('A', ['http://a/1']),
        ],
      );
      final a = channel('A', ['http://a/1']);
      final id = await repository.createCustomCategory('Mine');
      await repository.addToCustomCategory(id, [a.key]);

      await repository.deletePlaylist(
        (await repository.getPlaylists()).single.id,
      );

      expect(
        (await repository.getCustomCategories()).single.channelKeys,
        isEmpty,
      );
    });
  });

  group('migration', () {
    test('v1 to v4 keeps channels, order and URLs', () async {
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

      await v1.transaction((txn) => ChannelDatabase.upgrade(txn, 1, 4));

      final all = await SqfliteChannelRepository(v1).getAll();
      expect(all.map((c) => c.name), ['Z', 'A', 'M']);
      expect(all.first.urls, ['http://x/Z']);
      expect(all.first.key, sha1Of('Z'));
      expect(all.first.favorite, isFalse);
      await v1.close();
    });

    test('v3 to v4 keeps channels and adds the new columns', () async {
      final v3 = await openMemory();
      await v3.execute(v1Schema);
      await v3.transaction((txn) => ChannelDatabase.upgrade(txn, 1, 3));
      await v3.insert('CHANNELS', {
        'key': 'k',
        'name': 'A',
        'category': 'News',
        'favorite': 1,
      });
      await v3.insert('SOURCES', {
        'channel_key': 'k',
        'position': 0,
        'url': 'http://a/1',
      });

      await v3.transaction((txn) => ChannelDatabase.upgrade(txn, 3, 4));

      final repo = SqfliteChannelRepository(v3);
      final channel = (await repo.getAll()).single;
      expect(channel.favorite, isTrue);
      expect(channel.hidden, isFalse);
      expect(channel.sources.single.hasHeaders, isFalse);
      expect(await repo.getCustomCategories(), isEmpty);
      expect(await repo.getHiddenCategories(), isEmpty);
      await v3.close();
    });

    test('v2 to v4 keeps sources as added by hand', () async {
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

      await v2.transaction((txn) => ChannelDatabase.upgrade(txn, 2, 4));

      final repo = SqfliteChannelRepository(v2);
      expect((await repo.getAll()).single.urls, ['http://a/1']);
      expect(await repo.getPlaylists(), isEmpty);
      await v2.close();
    });
  });

  test('imports a large playlist in one batch', () async {
    final channels = [
      for (var i = 0; i < 12000; i++)
        channel('Channel $i', ['http://x/$i', 'http://y/$i'], 'G${i % 9}'),
    ];

    final result = await repository.addPlaylist(
      name: 'big',
      channels: channels,
    );
    // Again: everything already exists, only new sources are added.
    final again = await repository.import([
      channel('Channel 5', ['http://x/5', 'http://z/5']),
    ]);

    expect(result.added, 12000);
    expect(again.updated, 1);
    final all = await repository.getAll();
    expect(all, hasLength(12000));
    expect(all[5].urls, ['http://x/5', 'http://y/5', 'http://z/5']);
    expect((await repository.getPlaylists()).single.sourceCount, 24000);
  });
}
